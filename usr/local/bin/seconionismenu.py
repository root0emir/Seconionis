#!/usr/bin/env python3
import sys
import subprocess
import os
from PyQt5.QtWidgets import (QApplication, QMainWindow, QPushButton, QVBoxLayout, 
                             QWidget, QLabel, QHBoxLayout, QMessageBox, 
                             QFrame, QGridLayout, QSizePolicy)
from PyQt5.QtGui import QPixmap, QIcon
from PyQt5.QtCore import Qt

# Developer root0emir 
# Securonis Linux Tor Traffic Router GUI Menu 
# Seconionis Version 1.4

class SeconionisGUI(QMainWindow):
    def __init__(self):
        super().__init__()
        self.initUI()
        self.applyStyles()
        
    def initUI(self):
        """Initialize user interface components"""
        self.setWindowTitle("Seconionis")
        self.setFixedSize(400, 460) 
        
       
        central_widget = QWidget()
        self.setCentralWidget(central_widget)
        main_layout = QVBoxLayout(central_widget)
        main_layout.setSpacing(3) 
        main_layout.setContentsMargins(15, 2, 15, 10) 
        
      
        header_layout = QHBoxLayout()
        header_layout.setContentsMargins(0, 0, 0, 0)
        header_layout.setSpacing(3) 
        

        logo_title_layout = QHBoxLayout()
        logo_title_layout.setAlignment(Qt.AlignCenter)
        logo_title_layout.setSpacing(8)
        logo_title_layout.setContentsMargins(0, 0, 0, 0)  
        
   
        logo_label = QLabel()
        logo_label.setAlignment(Qt.AlignCenter)
        logo_label.setContentsMargins(0, 0, 0, 0) 
        
        
        title_label = QLabel("SECONIONIS")
        title_label.setAlignment(Qt.AlignCenter)
        title_label.setContentsMargins(0, 0, 0, 0)  
        title_label.setStyleSheet("font-size: 24px; font-weight: bold; color: #2ECC71; margin: 0;")
        

        if os.path.exists("seconionis.png"):
            pixmap = QPixmap("seconionis.png")
            logo_label.setPixmap(pixmap.scaled(50, 50, Qt.KeepAspectRatio, Qt.SmoothTransformation))  
        else:
            logo_label.setText("!")
            logo_label.setStyleSheet("color: #FF5555; font-size: 24px;")
        
      
        logo_title_layout.addWidget(logo_label)
        logo_title_layout.addWidget(title_label)
        
        header_widget = QWidget()
        header_widget.setLayout(logo_title_layout)
        header_widget.setContentsMargins(0, 0, 0, 0)
        header_layout.addStretch(1)
        header_layout.addWidget(header_widget)
        header_layout.addStretch(1)
        

        margin_box = QWidget()
        margin_box.setFixedHeight(2)  
        
       
        main_layout.addLayout(header_layout)
        main_layout.addWidget(margin_box) 
        
        main_layout.addLayout(self.createButtonGrid())
        
    def createButtonGrid(self):
        """Create the grid of buttons"""
        grid_layout = QGridLayout()
        grid_layout.setSpacing(8) 
        grid_layout.setContentsMargins(0, 0, 0, 0)  
        
        buttons = [
            ("Start Tor Routing", "start"),
            ("Stop Tor Routing", "stop"),
            ("Tor Status", "status"),
            ("Restart Tor", "restart"),
            ("Set Autowipe", "autowipe"),
            ("Disable Autowipe", "disable-autowipe"),
            ("Set Autostart", "autostart"),
            ("Disable Autostart", "disable-autostart"),
            ("Get IP", "ip"),
            ("Change Tor ID", "changeid"),
            ("Change MAC", "changemac"),
            ("Reset MAC", "revertmac"),
            ("Version", "version"),
            ("About", "about"),
            ("Exit", "exit")
        ]
        
        for i, (text, cmd) in enumerate(buttons):
            button = QPushButton(text)
            button.setFixedHeight(45) 
            
            if cmd == "exit":
                button.clicked.connect(self.close)
            elif cmd == "about":
                button.clicked.connect(self.show_about)
            else:
                button.clicked.connect(lambda checked=False, c=cmd: self.run_command(c))
            
            row, col = divmod(i, 3)
            grid_layout.addWidget(button, row, col)
        
        return grid_layout
    
    def applyStyles(self):
        """Apply CSS styling to the application"""
        self.setStyleSheet("""
            QMainWindow, QWidget {
                background-color: #121212;
                color: #2ECC71;
                font-family: 'Segoe UI', 'Arial', sans-serif;
            }
            
            QLabel {
                color: #2ECC71;
                padding: 0px; 
                margin: 0px;
            }
            
            QPushButton {
                background-color: #101010;
                color: #2ECC71;
                font-size: 12px;
                font-weight: bold;
                border: 1px solid #2a2a2a;
                border-radius: 6px;
                padding: 6px;  /* Daha da az iç dolgu */
                margin: 2px;   /* Minimum kenar boşluğu */
            }
            
            QPushButton:hover {
                background-color: #171717;
                border: 1px solid #2ECC71;
            }
            
            QPushButton:pressed {
                background-color: #0a0a0a;
                border: 1px solid #27AE60;
            }
            
            /* Different button color tints */
            QPushButton:nth-child(4n+1) {
                background-color: #121212;
            }
            QPushButton:nth-child(4n+1):hover {
                background-color: #171717;
            }
            
            QPushButton:nth-child(4n+2) {
                background-color: #141414;
            }
            QPushButton:nth-child(4n+2):hover {
                background-color: #191919;
            }
            
            QPushButton:nth-child(4n+3) {
                background-color: #161616;
            }
            QPushButton:nth-child(4n+3):hover {
                background-color: #1B1B1B;
            }
            
            QPushButton:nth-child(4n+4) {
                background-color: #181818;
            }
            QPushButton:nth-child(4n+4):hover {
                background-color: #1D1D1D;
            }
            
            /* Last button (Exit) */
            QPushButton:last-child {
                background-color: #1A1A1A;
                color: #E74C3C;
                border: 1px solid #2a2a2a;
            }
            QPushButton:last-child:hover {
                background-color: #1F1F1F;
                border: 1px solid #E74C3C;
            }
        """)
    
    def run_command(self, command):
        """Execute seconionis command and show results"""
        try:
            # Run command
            result = subprocess.run(["/usr/bin/seconionis", command], 
                                   capture_output=True, text=True, check=True)
            
            # Show result
            self.show_message("Operation Result", result.stdout, QMessageBox.Information)
            
        except subprocess.CalledProcessError as e:
            self.show_message("Error", f"Command error:\n{e.stderr}", QMessageBox.Warning)
        except Exception as e:
            self.show_message("Error", f"System error:\n{str(e)}", QMessageBox.Critical)
    
    def show_about(self):
        """Display about information"""
        about_text = """Seconionis is a tool that forces all system traffic through the Tor network by using a Tor transparent proxy.

Author: root0emir
Github: https://github.com/Securonis/Seconionis"""
        
        self.show_message("About Seconionis", about_text, QMessageBox.Information)
    
    def show_message(self, title, message, icon):
        """Display a styled message box"""
        msg_box = QMessageBox(self)
        msg_box.setWindowTitle(title)
        msg_box.setText(message)
        msg_box.setIcon(icon)
        msg_box.setStyleSheet("""
            QMessageBox {
                background-color: #121212;
                color: #2ECC71;
            }
            QLabel {
                color: #2ECC71;
                font-size: 14px;
            }
            QPushButton {
                background-color: #101010;
                color: #2ECC71;
                font-size: 12px;
                min-width: 70px;
                min-height: 25px;
                border: 1px solid #2a2a2a;
                border-radius: 5px;
            }
            QPushButton:hover {
                background-color: #171717;
                border: 1px solid #2ECC71;
            }
        """)
        msg_box.exec_()

def main():
    app = QApplication(sys.argv)
    
    # Application icon
    if os.path.exists("/usr/share/icons/securonis/seconionis.png"):
        app.setWindowIcon(QIcon("/usr/share/icons/securonis/seconionis.png"))
    
    window = SeconionisGUI()
    window.show()
    sys.exit(app.exec_())

if __name__ == "__main__":
    main() 
