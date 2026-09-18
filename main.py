"""
Windows desktop dashboard for the Opportunity & PE/VC/Impact/Consulting digest.
Built with PySide6 (Qt for Python) + QML.

Setup:
  pip install -r requirements-desktop.txt
  Fill in .env (TAVILY_API_KEY, GROQ_API_KEY, DIGEST_TO_EMAIL, SMTP_*)
  python main.py

This imports digest_engine.py directly from this folder — no Flask
server needed for the desktop app, it's all in-process.
"""

import sys
import threading
from datetime import date
from pathlib import Path

from PySide6.QtCore import QObject, Signal, Slot, Property, QUrl
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine

# Make the sibling digest_engine.py (in this same folder) importable.
sys.path.insert(0, str(Path(__file__).parent))
import digest_engine  # noqa: E402
from config import load_env, save_env  # noqa: E402


class DigestBackend(QObject):
    jobsChanged = Signal()
    newsChanged = Signal()
    statusChanged = Signal()
    dateLabelChanged = Signal()
    busyChanged = Signal()
    settingsChanged = Signal()
    historyChanged = Signal()

    def __init__(self):
        super().__init__()
        self._jobs = []
        self._news = []
        self._history = []
        self._status = "Ready."
        self._date_label = "No scan run yet"
        self._busy = False
        self._recipient_email = ""
        self._smtp_host = ""
        self._smtp_port = ""
        self._smtp_user = ""
        self._smtp_pass = ""
        self._tavily_key = ""
        self._groq_key = ""
        self._groq_model = ""
        self._job_queries_text = ""
        self._news_queries_text = ""
        self.loadSettings()
        self.loadHistory()

    # -- Qt properties exposed to QML -------------------------------------

    @Property("QVariantList", notify=jobsChanged)
    def jobs(self):
        return self._jobs

    @Property("QVariantList", notify=newsChanged)
    def news(self):
        return self._news

    @Property("QVariantList", notify=historyChanged)
    def history(self):
        return self._history

    @Property(str, notify=statusChanged)
    def status(self):
        return self._status

    @Property(str, notify=dateLabelChanged)
    def dateLabel(self):
        return self._date_label

    @Property(bool, notify=busyChanged)
    def busy(self):
        return self._busy

    @Property(str, notify=settingsChanged)
    def recipientEmail(self):
        return self._recipient_email

    @Property(str, notify=settingsChanged)
    def smtpHost(self):
        return self._smtp_host

    @Property(str, notify=settingsChanged)
    def smtpPort(self):
        return self._smtp_port

    @Property(str, notify=settingsChanged)
    def smtpUser(self):
        return self._smtp_user

    @Property(str, notify=settingsChanged)
    def smtpPass(self):
        return self._smtp_pass

    @Property(str, notify=settingsChanged)
    def tavilyKey(self):
        return self._tavily_key

    @Property(str, notify=settingsChanged)
    def groqKey(self):
        return self._groq_key

    @Property(str, notify=settingsChanged)
    def groqModel(self):
        return self._groq_model

    @Property(str, notify=settingsChanged)
    def jobQueriesText(self):
        return self._job_queries_text

    @Property(str, notify=settingsChanged)
    def newsQueriesText(self):
        return self._news_queries_text

    # -- internal helpers ---------------------------------------------------

    def _set_status(self, text: str):
        self._status = text
        self.statusChanged.emit()

    def _set_busy(self, value: bool):
        self._busy = value
        self.busyChanged.emit()

    # -- actions callable from QML ------------------------------------------

    @Slot()
    def runScan(self):
        if self._busy:
            return
        self._set_busy(True)
        self._set_status("Scanning for new listings and news…")

        def worker():
            try:
                _html_path, _sent, jobs, news = digest_engine.run_digest(
                    log=self._set_status, dry_run=True
                )
                self._jobs = jobs
                self._news = news
                self._date_label = date.today().strftime("%A %d %B %Y")
                self.jobsChanged.emit()
                self.newsChanged.emit()
                self.dateLabelChanged.emit()
                self.loadHistory()
                self._set_status(
                    f"Found {len(self._jobs)} new roles and {len(self._news)} news items."
                )
            except Exception as e:
                self._set_status(f"Scan failed: {e}")
            finally:
                self._set_busy(False)

        threading.Thread(target=worker, daemon=True).start()

    @Slot()
    def sendEmail(self):
        if self._busy:
            return
        self._set_busy(True)
        self._set_status("Sending email…")

        def worker():
            try:
                digest_engine.finalize_and_send(self._jobs, self._news, log=self._set_status)
                self._set_status("Digest emailed.")
                self.loadHistory()
            except Exception as e:
                self._set_status(f"Email failed: {e}")
            finally:
                self._set_busy(False)

        threading.Thread(target=worker, daemon=True).start()

    @Slot()
    def loadHistory(self):
        self._history = digest_engine.load_history()
        self.historyChanged.emit()

    @Slot()
    def loadSettings(self):
        env = load_env()
        self._recipient_email = env.get("DIGEST_TO_EMAIL", "")
        self._smtp_host = env.get("SMTP_HOST", "")
        self._smtp_port = env.get("SMTP_PORT", "")
        self._smtp_user = env.get("SMTP_USER", "")
        self._smtp_pass = env.get("SMTP_PASS", "")
        self._tavily_key = env.get("TAVILY_API_KEY", "")
        self._groq_key = env.get("GROQ_API_KEY", "")
        self._groq_model = env.get("GROQ_MODEL", "")
        job_queries, news_queries = digest_engine.load_queries()
        self._job_queries_text = "\n".join(job_queries)
        self._news_queries_text = "\n".join(news_queries)
        self.settingsChanged.emit()

    @Slot(str, str, str, str, str, str, str, str, str, str)
    def saveSettings(self, recipient_email, smtp_host, smtp_port, smtp_user, smtp_pass,
                      tavily_key, groq_key, groq_model, job_queries_text, news_queries_text):
        try:
            save_env({
                "DIGEST_TO_EMAIL": recipient_email,
                "SMTP_HOST": smtp_host,
                "SMTP_PORT": smtp_port,
                "SMTP_USER": smtp_user,
                "SMTP_PASS": smtp_pass,
                "TAVILY_API_KEY": tavily_key,
                "GROQ_API_KEY": groq_key,
                "GROQ_MODEL": groq_model,
            })
            job_queries = [q.strip() for q in job_queries_text.split("\n") if q.strip()]
            news_queries = [q.strip() for q in news_queries_text.split("\n") if q.strip()]
            digest_engine.save_queries(job_queries, news_queries)
            self.loadSettings()
            self._set_status("Settings saved.")
        except Exception as e:
            self._set_status(f"Save failed: {e}")


def main():
    app = QGuiApplication(sys.argv)
    app.setApplicationName("JobHuntAI")

    engine = QQmlApplicationEngine()
    backend = DigestBackend()
    engine.rootContext().setContextProperty("backend", backend)

    qml_path = Path(__file__).parent / "Main.qml"
    engine.load(QUrl.fromLocalFile(str(qml_path)))

    if not engine.rootObjects():
        sys.exit(-1)

    sys.exit(app.exec())


if __name__ == "__main__":
    main()
