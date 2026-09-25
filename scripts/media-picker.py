#!/usr/bin/env python3
"""
Desktop background media picker dialog for pranc-shell.
Presents a native file picker dialog matching Hyprland's 'Choose wallpaper' window rules.
Allows selection of images and videos with live preview panel, metadata display,
and instant background application via Quickshell IPC.
"""

import os
import sys
import io
import subprocess
from PIL import Image
from PyQt5.QtCore import Qt, QDir, QSize
from PyQt5.QtGui import QImage, QPixmap
from PyQt5.QtWidgets import (
    QApplication, QDialog, QVBoxLayout, QHBoxLayout, QPushButton,
    QLabel, QSplitter, QFileSystemModel, QListView, QComboBox,
    QFrame, QSizePolicy
)

IMAGE_EXTENSIONS = {".jpg", ".jpeg", ".png", ".webp", ".avif", ".bmp", ".svg", ".gif"}
VIDEO_EXTENSIONS = {".mp4", ".webm", ".mkv", ".mov", ".avi"}
ALL_MEDIA_EXTENSIONS = IMAGE_EXTENSIONS | VIDEO_EXTENSIONS

class MediaPickerWindow(QDialog):
    def __init__(self, parent=None):
        super().__init__(parent)
        self.setWindowTitle("Choose wallpaper")
        self.resize(1100, 680)
        self.selected_path = None

        home = os.path.expanduser("~")
        candidates = [
            os.path.join(home, "Pictures", "Wallpapers"),
            os.path.join(home, "Pictures", "wallpaper"),
            os.path.join(home, "Pictures"),
            home
        ]
        self.current_dir = home
        for c in candidates:
            if os.path.isdir(c):
                self.current_dir = c
                break

        self.init_ui()
        self.apply_theme()
        self.navigate_to(self.current_dir)

    def init_ui(self):
        main_layout = QVBoxLayout(self)
        main_layout.setContentsMargins(14, 14, 14, 14)
        main_layout.setSpacing(10)

        # 1. Top Navigation Bar
        top_bar = QHBoxLayout()
        top_bar.setSpacing(8)

        self.btn_up = QPushButton("▲ Up")
        self.btn_up.clicked.connect(self.go_up)
        top_bar.addWidget(self.btn_up)

        # Quick Links
        home = os.path.expanduser("~")
        for label, path in [
            ("Wallpapers", os.path.join(home, "Pictures", "Wallpapers")),
            ("Wallpaper Dir", os.path.join(home, "Pictures", "wallpaper")),
            ("Pictures", os.path.join(home, "Pictures")),
            ("Videos", os.path.join(home, "Videos")),
            ("Home", home),
        ]:
            if os.path.isdir(path):
                btn = QPushButton(label)
                btn.clicked.connect(lambda checked, p=path: self.navigate_to(p))
                top_bar.addWidget(btn)

        self.path_label = QLabel(self.current_dir)
        self.path_label.setStyleSheet("color: #a0a0b8; font-weight: bold; padding-left: 8px;")
        top_bar.addWidget(self.path_label, 1)

        main_layout.addLayout(top_bar)

        # 2. Main Content: Splitter (File List | Preview Panel)
        splitter = QSplitter(Qt.Horizontal)

        # Left: File System List
        self.model = QFileSystemModel()
        self.model.setRootPath(QDir.rootPath())
        self.model.setFilter(QDir.AllDirs | QDir.Files | QDir.NoDotAndDotDot)
        self.update_name_filters()

        self.list_view = QListView()
        self.list_view.setModel(self.model)
        self.list_view.setIconSize(QSize(24, 24))
        self.list_view.clicked.connect(self.on_item_clicked)
        self.list_view.doubleClicked.connect(self.on_item_double_clicked)
        splitter.addWidget(self.list_view)

        # Right: Preview Panel
        preview_container = QFrame()
        preview_container.setObjectName("previewContainer")
        preview_layout = QVBoxLayout(preview_container)
        preview_layout.setContentsMargins(16, 16, 16, 16)
        preview_layout.setSpacing(10)

        preview_title = QLabel("Media Preview")
        preview_title.setStyleSheet("font-size: 15px; font-weight: bold; color: #ffffff;")
        preview_layout.addWidget(preview_title)

        self.preview_image = QLabel("Select an image or video to preview")
        self.preview_image.setAlignment(Qt.AlignCenter)
        self.preview_image.setStyleSheet("background: #0d0d12; border: 1px solid #2a2a3c; border-radius: 8px; color: #707088;")
        self.preview_image.setMinimumSize(420, 320)
        self.preview_image.setSizePolicy(QSizePolicy.Expanding, QSizePolicy.Expanding)
        preview_layout.addWidget(self.preview_image, 1)

        # Metadata
        self.lbl_filename = QLabel("No file selected")
        self.lbl_filename.setWordWrap(True)
        self.lbl_filename.setStyleSheet("font-weight: bold; color: #e0e0ff; font-size: 13px;")
        preview_layout.addWidget(self.lbl_filename)

        self.lbl_meta = QLabel("")
        self.lbl_meta.setStyleSheet("color: #9090aa; font-size: 12px;")
        preview_layout.addWidget(self.lbl_meta)

        splitter.addWidget(preview_container)
        splitter.setStretchFactor(0, 3)
        splitter.setStretchFactor(1, 2)
        main_layout.addWidget(splitter, 1)

        # 3. Bottom Action Bar
        bottom_bar = QHBoxLayout()
        bottom_bar.setSpacing(10)

        lbl_filter = QLabel("Filter:")
        lbl_filter.setStyleSheet("color: #a0a0b8;")
        bottom_bar.addWidget(lbl_filter)

        self.filter_combo = QComboBox()
        self.filter_combo.addItems([
            "Supported Media (*.jpg, *.png, *.webp, *.mp4...)",
            "Images Only (*.jpg, *.png, *.webp, *.gif...)",
            "Videos Only (*.mp4, *.webm, *.mkv...)",
            "All Files (*)"
        ])
        self.filter_combo.currentIndexChanged.connect(self.update_name_filters)
        bottom_bar.addWidget(self.filter_combo)

        bottom_bar.addStretch()

        self.btn_cancel = QPushButton("Cancel")
        self.btn_cancel.clicked.connect(self.reject)
        bottom_bar.addWidget(self.btn_cancel)

        self.btn_apply = QPushButton("Apply Background")
        self.btn_apply.setObjectName("applyButton")
        self.btn_apply.setEnabled(False)
        self.btn_apply.clicked.connect(self.apply_and_close)
        bottom_bar.addWidget(self.btn_apply)

        main_layout.addLayout(bottom_bar)

    def apply_theme(self):
        self.setStyleSheet("""
            QDialog {
                background-color: #14141e;
                color: #e6e6f0;
                font-family: sans-serif;
            }
            QPushButton {
                background-color: #222232;
                color: #e6e6f0;
                border: 1px solid #333348;
                border-radius: 6px;
                padding: 6px 14px;
                font-size: 13px;
            }
            QPushButton:hover {
                background-color: #2e2e44;
                border-color: #4a4a68;
            }
            QPushButton:disabled {
                background-color: #1a1a24;
                color: #555566;
                border-color: #222230;
            }
            QPushButton#applyButton {
                background-color: #5d4ec7;
                border: 1px solid #7c6fcd;
                color: #ffffff;
                font-weight: bold;
                padding: 6px 20px;
            }
            QPushButton#applyButton:hover {
                background-color: #6d5ed7;
            }
            QPushButton#applyButton:disabled {
                background-color: #2a2644;
                border-color: #383454;
                color: #666088;
            }
            QListView {
                background-color: #181824;
                border: 1px solid #2a2a3c;
                border-radius: 8px;
                color: #e6e6f0;
                padding: 6px;
                font-size: 13px;
            }
            QListView::item {
                padding: 6px 8px;
                border-radius: 4px;
            }
            QListView::item:selected {
                background-color: #383458;
                color: #ffffff;
            }
            QListView::item:hover:!selected {
                background-color: #222234;
            }
            QFrame#previewContainer {
                background-color: #181824;
                border: 1px solid #2a2a3c;
                border-radius: 8px;
            }
            QComboBox {
                background-color: #222232;
                color: #e6e6f0;
                border: 1px solid #333348;
                border-radius: 6px;
                padding: 4px 10px;
            }
            QComboBox::drop-down {
                border: none;
            }
            QComboBox QAbstractItemView {
                background-color: #1c1c28;
                color: #e6e6f0;
                border: 1px solid #333348;
                selection-background-color: #383458;
            }
        """)

    def update_name_filters(self):
        idx = self.filter_combo.currentIndex() if hasattr(self, 'filter_combo') else 0
        if idx == 0:
            filters = [f"*{ext}" for ext in ALL_MEDIA_EXTENSIONS]
        elif idx == 1:
            filters = [f"*{ext}" for ext in IMAGE_EXTENSIONS]
        elif idx == 2:
            filters = [f"*{ext}" for ext in VIDEO_EXTENSIONS]
        else:
            filters = ["*"]
        self.model.setNameFilters(filters)
        self.model.setNameFilterDisables(False)

    def navigate_to(self, path):
        if os.path.isdir(path):
            self.current_dir = os.path.abspath(path)
            self.path_label.setText(self.current_dir)
            self.model.setRootPath(self.current_dir)
            self.list_view.setRootIndex(self.model.index(self.current_dir))

    def go_up(self):
        parent = os.path.dirname(self.current_dir)
        if parent and os.path.isdir(parent) and parent != self.current_dir:
            self.navigate_to(parent)

    def on_item_clicked(self, index):
        file_path = self.model.filePath(index)
        if os.path.isfile(file_path):
            self.show_preview(file_path)
            self.selected_path = file_path
            self.btn_apply.setEnabled(True)
        else:
            self.clear_preview()
            self.selected_path = None
            self.btn_apply.setEnabled(False)

    def on_item_double_clicked(self, index):
        file_path = self.model.filePath(index)
        if os.path.isdir(file_path):
            self.navigate_to(file_path)
        elif os.path.isfile(file_path):
            self.selected_path = file_path
            self.apply_and_close()

    def show_preview(self, file_path):
        filename = os.path.basename(file_path)
        self.lbl_filename.setText(filename)
        _, ext = os.path.splitext(filename.lower())
        size_bytes = os.path.getsize(file_path)
        size_mb = size_bytes / (1024 * 1024)

        if ext in IMAGE_EXTENSIONS:
            try:
                im = Image.open(file_path)
                w, h = im.width, im.height
                im.thumbnail((500, 380), Image.Resampling.LANCZOS)
                im = im.convert("RGBA")
                data = im.tobytes("raw", "RGBA")
                qimg = QImage(data, im.width, im.height, QImage.Format_RGBA8888)
                pix = QPixmap.fromImage(qimg)
                self.preview_image.setPixmap(pix)
                self.lbl_meta.setText(f"Type: Image ({ext[1:].upper()})   |   Resolution: {w} × {h}   |   Size: {size_mb:.2f} MB")
                return
            except Exception as e:
                self.preview_image.setText(f"Preview unavailable\n({e})")
                self.lbl_meta.setText(f"Type: Image ({ext[1:].upper()})   |   Size: {size_mb:.2f} MB")
                return

        elif ext in VIDEO_EXTENSIONS:
            try:
                cmd = [
                    "ffmpeg", "-y", "-ss", "00:00:01", "-i", file_path,
                    "-vframes", "1", "-f", "image2pipe", "-vcodec", "png", "-"
                ]
                res = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
                if res.returncode == 0 and res.stdout:
                    im = Image.open(io.BytesIO(res.stdout))
                    w, h = im.width, im.height
                    im.thumbnail((500, 380), Image.Resampling.LANCZOS)
                    im = im.convert("RGBA")
                    data = im.tobytes("raw", "RGBA")
                    qimg = QImage(data, im.width, im.height, QImage.Format_RGBA8888)
                    pix = QPixmap.fromImage(qimg)
                    self.preview_image.setPixmap(pix)
                    self.lbl_meta.setText(f"Type: Video ({ext[1:].upper()})   |   Resolution: {w} × {h}   |   Size: {size_mb:.2f} MB")
                    return
            except Exception:
                pass
            self.preview_image.setText("Video file (Preview generation failed)")
            self.lbl_meta.setText(f"Type: Video ({ext[1:].upper()})   |   Size: {size_mb:.2f} MB")
            return

        self.preview_image.setText("Not a recognized media file")
        self.lbl_meta.setText(f"Size: {size_mb:.2f} MB")

    def clear_preview(self):
        self.preview_image.clear()
        self.preview_image.setText("Select an image or video to preview")
        self.lbl_filename.setText("No file selected")
        self.lbl_meta.setText("")

    def apply_and_close(self):
        if self.selected_path and os.path.exists(self.selected_path):
            print(self.selected_path)
            # Dispatch to pranc-shell IPC with correct space-separated arguments
            try:
                subprocess.run(
                    ["qs", "-c", "pranc-shell", "ipc", "call", "wallpaper", "setMedia", self.selected_path],
                    stdout=subprocess.DEVNULL,
                    stderr=subprocess.DEVNULL,
                    check=False
                )
            except Exception:
                pass
            self.accept()

def main():
    app = QApplication(sys.argv)
    win = MediaPickerWindow()
    win.show()
    sys.exit(app.exec_())

if __name__ == "__main__":
    main()
