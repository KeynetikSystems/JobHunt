"""
Windows desktop dashboard for the Opportunity & PE/VC/Impact/Consulting digest.
Built with PySide6 (Qt for Python) + QML.

Setup:
  pip install -r requirements-desktop.txt
  python main.py
  Connect to your backend from the Settings page (Backend URL + email) — the desktop
  app no longer holds its own Tavily/Groq/SMTP keys or runs digest_engine.py in-process.
  Every action goes through backend/app.py, the same server the mobile app uses, so
  desktop users share the operator's keys and the same free/premium caps apply.
"""

import sys
import threading
from datetime import date
from pathlib import Path

from PySide6.QtCore import QObject, Signal, Slot, Property, QUrl
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine

import backend_client
from config import load_env, save_env

# Rank used to sort jobs by seniority — lower is more junior, matching the mobile
# app's seniorityRankOf(). Anything unrecognized sorts last.
_DEFAULT_BACKEND_URL = "https://jobhuntai-production-ed1d.up.railway.app"

_SENIORITY_RANK = {
    "Graduate/Intern": 0,
    "Analyst/Junior": 1,
    "Associate/Mid": 2,
    "Manager/Senior": 3,
    "Director/Partner+": 4,
}


def _friendly_error(e: Exception) -> str:
    """Plain-language text for the handful of network failures users actually hit,
    instead of a raw stringified exception — mirrors the mobile app's friendlyError().
    backend_client.BackendError already extracts the server's own error detail where
    possible; this only normalizes network-level failures underneath that."""
    msg = str(e)
    lower = msg.lower()
    if any(s in lower for s in (
        "urlerror", "connection refused", "getaddrinfo failed", "name or service not known",
        "timed out", "certificate verify failed", "couldn't reach the server",
    )):
        return "Couldn't reach the server — check your connection and backend URL in Settings."
    return msg


class DigestBackend(QObject):
    jobsChanged = Signal()
    newsChanged = Signal()
    statusChanged = Signal()
    dateLabelChanged = Signal()
    busyChanged = Signal()
    settingsChanged = Signal()
    historyChanged = Signal()
    materialsChanged = Signal()
    accountChanged = Signal()

    def __init__(self):
        super().__init__()
        self._jobs = []
        self._news = []
        self._history = []
        self._materials = {}
        self._account = {}
        self._status = "Ready."
        self._date_label = "No scan run yet"
        self._busy = False
        self._backend_url = ""
        self._api_key = ""
        self._email = ""
        self._profile = {}
        self._seniority_descending = False
        self.loadSettings()
        # Actual first refresh happens from QML's Component.onCompleted (backend.refreshAccount()),
        # once the window has loaded — refreshAccount() itself is a no-op if not connected.

    # -- Qt properties exposed to QML -------------------------------------

    @Property("QVariantList", notify=jobsChanged)
    def jobs(self):
        return sorted(
            self._jobs,
            key=lambda j: _SENIORITY_RANK.get(j.get("seniority"), 99),
            reverse=self._seniority_descending,
        )

    @Property(bool, notify=jobsChanged)
    def seniorityDescending(self):
        return self._seniority_descending

    @Property("QVariantList", notify=newsChanged)
    def news(self):
        return self._news

    @Property("QVariantList", notify=historyChanged)
    def history(self):
        return self._history

    @Property("QVariantMap", notify=materialsChanged)
    def materials(self):
        return self._materials

    @Property(str, notify=statusChanged)
    def status(self):
        return self._status

    @Property(str, notify=dateLabelChanged)
    def dateLabel(self):
        return self._date_label

    @Property(bool, notify=busyChanged)
    def busy(self):
        return self._busy

    @Property(bool, notify=settingsChanged)
    def connected(self):
        return bool(self._backend_url and self._api_key)

    @Property(str, notify=settingsChanged)
    def backendUrl(self):
        return self._backend_url

    @Property(str, notify=settingsChanged)
    def email(self):
        return self._email

    @Property("QVariantMap", notify=settingsChanged)
    def profile(self):
        return self._profile

    @Property("QVariantMap", notify=accountChanged)
    def account(self):
        return self._account

    # -- internal helpers ---------------------------------------------------

    def _set_status(self, text: str):
        self._status = text
        self.statusChanged.emit()

    def _set_busy(self, value: bool):
        self._busy = value
        self.busyChanged.emit()

    def _find_job(self, url: str):
        for item in (*self._jobs, *self._history):
            if item.get("url") == url and item.get("kind", "job") == "job":
                return item
        return None

    def _refresh_history_sync(self):
        """Runs on whatever thread calls it — either loadHistory()'s own worker thread,
        or reused directly from inside another action's worker (e.g. sendEmail) that's
        already off the GUI thread, to avoid spawning a redundant nested thread."""
        try:
            self._history = backend_client.history(self._backend_url, self._api_key)
            self.historyChanged.emit()
        except Exception:
            pass  # Not fatal — the History page just won't refresh this time.

    def _refresh_account_sync(self):
        """Fetches account status, profile, and history — called after connecting and
        whenever Settings wants a fresh read. Silent on failure, matching the mobile
        app's own _loadAccount/_loadProfile pattern: the Account section and profile
        fields just won't show/refresh until this next succeeds."""
        try:
            self._account = backend_client.me(self._backend_url, self._api_key)
            self.accountChanged.emit()
        except Exception:
            pass
        try:
            self._profile = backend_client.get_profile(self._backend_url, self._api_key)
            self.settingsChanged.emit()
        except Exception:
            pass
        self._refresh_history_sync()

    # -- actions callable from QML ------------------------------------------

    @Slot(str, str)
    def connect(self, base_url, email):
        if self._busy:
            return
        base_url = base_url.strip().rstrip("/")
        email = email.strip()
        self._set_busy(True)
        self._set_status("Connecting…")

        def worker():
            try:
                api_key = backend_client.register(base_url, email)
                self._backend_url = base_url
                self._api_key = api_key
                self._email = email
                save_env({"BACKEND_URL": base_url, "BACKEND_API_KEY": api_key, "BACKEND_EMAIL": email})
                self.settingsChanged.emit()
                self._set_status(f"Connected as {email}. Check your email to verify your account.")
                self._refresh_account_sync()
            except Exception as e:
                self._set_status(f"Connection failed: {_friendly_error(e)}")
            finally:
                self._set_busy(False)

        threading.Thread(target=worker, daemon=True).start()

    @Slot()
    def disconnect(self):
        self._backend_url = _DEFAULT_BACKEND_URL
        self._api_key = ""
        self._email = ""
        self._account = {}
        self._profile = {}
        self._jobs = []
        self._news = []
        self._history = []
        save_env({"BACKEND_URL": "", "BACKEND_API_KEY": "", "BACKEND_EMAIL": ""})
        self.settingsChanged.emit()
        self.accountChanged.emit()
        self.jobsChanged.emit()
        self.newsChanged.emit()
        self.historyChanged.emit()
        self._set_status("Disconnected.")

    @Slot()
    def refreshAccount(self):
        if not self.connected:
            return
        threading.Thread(target=self._refresh_account_sync, daemon=True).start()

    @Slot()
    def resendVerification(self):
        if self._busy:
            return
        self._set_busy(True)
        self._set_status("Sending…")

        def worker():
            try:
                backend_client.resend_verification(self._backend_url, self._api_key)
                self._set_status("Verification email sent — check your inbox.")
            except Exception as e:
                self._set_status(f"Failed: {_friendly_error(e)}")
            finally:
                self._set_busy(False)

        threading.Thread(target=worker, daemon=True).start()

    @Slot(str)
    def requestUpgrade(self, note):
        if self._busy:
            return
        self._set_busy(True)
        self._set_status("Sending…")

        def worker():
            try:
                backend_client.request_upgrade(self._backend_url, self._api_key, note)
                self._set_status("Request sent — we'll follow up by email.")
            except Exception as e:
                self._set_status(f"Failed: {_friendly_error(e)}")
            finally:
                self._set_busy(False)

        threading.Thread(target=worker, daemon=True).start()

    @Slot(str, str, str, str, str, str, str)
    def saveProfile(self, full_name, phone, location, linkedin_url, work_history, education, skills):
        if self._busy:
            return
        profile = {
            "full_name": full_name, "phone": phone, "location": location,
            "linkedin_url": linkedin_url, "work_history": work_history,
            "education": education, "skills": skills,
        }
        self._set_busy(True)
        self._set_status("Saving…")

        def worker():
            try:
                backend_client.save_profile(self._backend_url, self._api_key, profile)
                self._profile = profile
                self.settingsChanged.emit()
                self._set_status("Profile saved.")
            except Exception as e:
                self._set_status(f"Save failed: {_friendly_error(e)}")
            finally:
                self._set_busy(False)

        threading.Thread(target=worker, daemon=True).start()

    @Slot()
    def runScan(self):
        if self._busy:
            return
        if not self.connected:
            self._set_status("Not connected — connect to your backend in Settings first.")
            return
        self._set_busy(True)
        self._set_status("Checking the shared scan for new listings and news…")

        def worker():
            try:
                result = backend_client.scan(self._backend_url, self._api_key)
                self._jobs = result.get("jobs", [])
                self._news = result.get("news", [])
                self._date_label = date.today().strftime("%A %d %B %Y")
                self.jobsChanged.emit()
                self.newsChanged.emit()
                self.dateLabelChanged.emit()
                self._set_status(
                    f"Found {len(self._jobs)} new roles and {len(self._news)} news items."
                )
            except Exception as e:
                self._set_status(f"Scan failed: {_friendly_error(e)}")
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
                backend_client.send(self._backend_url, self._api_key, self._jobs, self._news)
                self._set_status("Digest emailed.")
                self._refresh_history_sync()
            except Exception as e:
                self._set_status(f"Email failed: {_friendly_error(e)}")
            finally:
                self._set_busy(False)

        threading.Thread(target=worker, daemon=True).start()

    @Slot(str)
    def draftApplicationMaterials(self, url):
        if self._busy:
            return
        job = self._find_job(url)
        if job is None:
            self._set_status("Couldn't find that listing anymore.")
            return
        self._set_busy(True)
        self._set_status(f"Drafting CV highlights and cover letter for {job.get('title', 'this role')}…")

        def worker():
            try:
                result = backend_client.materials(self._backend_url, self._api_key, job)
                self._materials = {**self._materials, url: result}
                self.materialsChanged.emit()
                self._set_status("Application materials ready.")
            except Exception as e:
                self._set_status(f"Drafting failed: {_friendly_error(e)}")
            finally:
                self._set_busy(False)

        threading.Thread(target=worker, daemon=True).start()

    @Slot()
    def toggleSenioritySort(self):
        self._seniority_descending = not self._seniority_descending
        self.jobsChanged.emit()

    @Slot(str)
    def dismissItem(self, url):
        """Per-card dismiss — marks one item seen without emailing the whole digest, the
        desktop equivalent of the mobile app's swipe-to-dismiss."""
        job = next((j for j in self._jobs if j.get("url") == url), None)
        news_item = next((n for n in self._news if n.get("url") == url), None)
        if job is None and news_item is None:
            return
        if job is not None:
            self._jobs = [j for j in self._jobs if j.get("url") != url]
            self.jobsChanged.emit()
        if news_item is not None:
            self._news = [n for n in self._news if n.get("url") != url]
            self.newsChanged.emit()
        try:
            backend_client.dismiss(
                self._backend_url, self._api_key,
                jobs=[job] if job is not None else [],
                news=[news_item] if news_item is not None else [],
            )
        except Exception as e:
            self._set_status(f"Dismiss didn't save ({_friendly_error(e)}) — it may reappear next scan.")

    @Slot(str)
    def runSearch(self, query):
        """Ad-hoc search — same mechanism as the mobile app's search box, going through
        the backend's (rate-limited) /api/search rather than local keys."""
        query = query.strip()
        if self._busy or not query:
            return
        if not self.connected:
            self._set_status("Not connected — connect to your backend in Settings first.")
            return
        self._set_busy(True)
        self._set_status(f'Searching for "{query}"…')

        def worker():
            try:
                result = backend_client.search(self._backend_url, self._api_key, query)
                self._jobs = result.get("jobs", [])
                self._news = result.get("news", [])
                self._date_label = date.today().strftime("%A %d %B %Y")
                self.jobsChanged.emit()
                self.newsChanged.emit()
                self.dateLabelChanged.emit()
                self._set_status(
                    f"Found {len(self._jobs)} new roles and {len(self._news)} news items."
                )
            except Exception as e:
                self._set_status(f"Search failed: {_friendly_error(e)}")
            finally:
                self._set_busy(False)

        threading.Thread(target=worker, daemon=True).start()

    @Slot()
    def loadHistory(self):
        if not self.connected:
            self._history = []
            self.historyChanged.emit()
            return
        threading.Thread(target=self._refresh_history_sync, daemon=True).start()

    @Slot()
    def loadSettings(self):
        env = load_env()
        # Pre-fills the Backend URL field so a fresh install doesn't require anyone to
        # know or type this — still fully editable in Settings for local dev, staging,
        # or if this ever moves. Never auto-connects on its own: connected requires a
        # real api_key too, which only exists after Connect is actually pressed.
        self._backend_url = env.get("BACKEND_URL") or _DEFAULT_BACKEND_URL
        self._api_key = env.get("BACKEND_API_KEY", "")
        self._email = env.get("BACKEND_EMAIL", "")
        self.settingsChanged.emit()


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
