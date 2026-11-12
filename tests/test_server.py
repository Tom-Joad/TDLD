"""Tests for the web UI (root/app/webui/server.py). Run: python3 -m unittest discover tests"""
import contextlib
import fcntl
import importlib.util
import io
import os
import socket
import tempfile
import threading
import time
import unittest
from unittest import mock
from http.server import ThreadingHTTPServer

HERE = os.path.dirname(os.path.abspath(__file__))
SERVER_PY = os.path.join(HERE, "..", "root", "app", "webui", "server.py")


def load_server(lists_dir, logs_dir, locks_dir):
    os.environ["LISTS_DIR"] = lists_dir
    os.environ["LOGS_DIR"] = logs_dir
    os.environ["LOCKS_DIR"] = locks_dir
    spec = importlib.util.spec_from_file_location("tdld_server", SERVER_PY)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class ServerTestCase(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.lists = os.path.join(self.tmp.name, "lists")
        self.logs = os.path.join(self.tmp.name, "logs")
        os.makedirs(self.lists)
        os.makedirs(self.logs)
        self.locks = os.path.join(self.tmp.name, "locks")
        self.server = load_server(self.lists, self.logs, self.locks)


class LogTests(ServerTestCase):
    def test_log_lines_have_a_time_stamp_and_are_flushed(self):
        out = io.StringIO()
        out.flush = mock.Mock(wraps=out.flush)
        with contextlib.redirect_stdout(out):
            self.server.log("hello")
        self.assertRegex(out.getvalue(), r"^\[\d{4}-\d\d-\d\d \d\d:\d\d:\d\d\] \[webui\] hello\n$")
        out.flush.assert_called()

    def test_tail_reads_only_the_last_lines(self):
        with open(os.path.join(self.logs, "channels.log"), "w") as f:
            for i in range(5000):
                f.write(f"line {i}\n")
        tail = self.server.read_log_tail("channels.log").splitlines()
        self.assertEqual(len(tail), self.server.LOG_TAIL_LINES)
        self.assertEqual(tail[-1], "line 4999")

    def test_missing_log(self):
        self.assertEqual(self.server.read_log_tail("channels.log"), "(no log yet)")


class DownloadTests(ServerTestCase):
    def setUp(self):
        super().setUp()
        bindir = os.path.join(self.tmp.name, "bin")
        os.makedirs(bindir)
        fake = os.path.join(bindir, "yt-dlp")
        with open(fake, "w") as f:
            f.write("#!/bin/sh\necho \"yt-dlp $*\"\nsleep \"${FAKE_SLEEP:-0.4}\"\n")
        os.chmod(fake, 0o755)
        patcher = mock.patch.dict(os.environ, {"PATH": bindir + os.pathsep + os.environ["PATH"]})
        patcher.start()
        self.addCleanup(patcher.stop)

    def wait_until_idle(self):
        deadline = time.monotonic() + 5
        while self.server.running_profiles() and time.monotonic() < deadline:
            time.sleep(0.05)
        self.assertEqual(self.server.running_profiles(), {})

    def test_second_download_on_the_same_profile_is_refused(self):
        self.assertTrue(self.server.start_download("channels", "https://example.com/a"))
        self.assertEqual(self.server.running_profiles(), {"channels": "manual"})
        self.assertFalse(self.server.start_download("channels", "https://example.com/b"))
        # Another profile is independent.
        self.assertTrue(self.server.start_download("playlists", "https://example.com/c"))
        self.wait_until_idle()
        with open(os.path.join(self.logs, "channels-manual.log")) as f:
            self.assertEqual(f.read().count("Manual download requested"), 1)

    def test_finished_download_is_reaped_and_the_lock_released(self):
        self.assertTrue(self.server.start_download("channels", "https://example.com/a"))
        self.wait_until_idle()
        self.assertEqual(self.server._running, {})
        self.assertTrue(self.server.start_download("channels", "https://example.com/b"))
        self.wait_until_idle()

    def test_download_is_refused_while_the_scheduled_run_holds_the_lock(self):
        os.makedirs(self.locks)
        fd = os.open(self.server.lock_path("channels"), os.O_RDWR | os.O_CREAT)
        self.addCleanup(os.close, fd)
        fcntl.flock(fd, fcntl.LOCK_EX)
        self.assertFalse(self.server.start_download("channels", "https://example.com/a"))
        self.assertEqual(self.server.running_profiles(), {"channels": "scheduled"})
        self.assertFalse(os.path.exists(os.path.join(self.logs, "channels-manual.log")))
        fcntl.flock(fd, fcntl.LOCK_UN)
        self.assertTrue(self.server.start_download("channels", "https://example.com/a"))
        self.wait_until_idle()

    def test_status_check_does_not_make_a_download_busy(self):
        # The status check takes each profile's lock for a moment. A download
        # started in that moment must wait for it, not be refused as busy.
        real_try_lock = self.server.try_lock
        probing = threading.Event()

        def slow_try_lock(profile):
            fd = real_try_lock(profile)
            if threading.current_thread() is not threading.main_thread() and profile == "channels":
                probing.set()
                time.sleep(0.3)
            return fd

        with mock.patch.object(self.server, "try_lock", side_effect=slow_try_lock):
            status = threading.Thread(target=self.server.running_profiles)
            status.start()
            self.assertTrue(probing.wait(2))
            started = self.server.start_download("channels", "https://example.com/a")
            status.join()
        self.assertTrue(started, "refused as busy while the status was checked")
        self.wait_until_idle()

    def test_large_manual_log_is_rotated(self):
        path = os.path.join(self.logs, "channels-manual.log")
        with open(path, "w") as f:
            f.write("x" * (self.server.MANUAL_LOG_MAX_BYTES + 1))
        self.assertTrue(self.server.start_download("channels", "https://example.com/a"))
        self.wait_until_idle()
        self.assertTrue(os.path.getsize(path + ".1") > self.server.MANUAL_LOG_MAX_BYTES)
        self.assertLess(os.path.getsize(path), 1000)


class WriteListTests(ServerTestCase):
    def test_writes_lines_and_trims_trailing_blank_lines(self):
        self.server.write_list("channels", "https://a\r\nhttps://b  \r\n\r\n")
        self.assertEqual(self.server.read_list("channels"), "https://a\nhttps://b\n")

    def test_no_temporary_file_is_left_behind(self):
        self.server.write_list("channels", "https://a\n")
        self.assertEqual(os.listdir(self.lists), ["channels.list"])

    def test_list_is_never_seen_empty_while_saving(self):
        path = self.server.list_path("channels")
        old = "".join(f"https://old.example/{i}\n" for i in range(2000))
        new = "".join(f"https://new.example/{i}\n" for i in range(2000))
        self.server.write_list("channels", old)
        stop = threading.Event()
        seen = []

        def reader():
            while not stop.is_set():
                with open(path) as f:
                    content = f.read()
                if content not in (old, new):
                    seen.append(len(content))

        thread = threading.Thread(target=reader)
        thread.start()
        try:
            for i in range(200):
                self.server.write_list("channels", new if i % 2 == 0 else old)
        finally:
            stop.set()
            thread.join()
        self.assertEqual(seen, [], "a reader saw an empty or partly written list")

    def test_failed_write_keeps_the_old_list(self):
        self.server.write_list("channels", "https://old\n")
        with mock.patch("os.replace", side_effect=OSError("disk full")):
            with self.assertRaises(OSError):
                self.server.write_list("channels", "https://new\n")
        self.assertEqual(self.server.read_list("channels"), "https://old\n")
        self.assertEqual(os.listdir(self.lists), ["channels.list"])

    def test_concurrent_saves_do_not_mix_lines(self):
        contents = ["".join(f"https://{n}.example/{i}\n" for i in range(500)) for n in "abcd"]
        threads = [
            threading.Thread(target=lambda c=c: [self.server.write_list("channels", c) for _ in range(30)])
            for c in contents
        ]
        for t in threads:
            t.start()
        for t in threads:
            t.join()
        self.assertIn(self.server.read_list("channels"), contents)

    def test_keeps_the_mode_of_an_existing_list(self):
        path = self.server.list_path("channels")
        with open(path, "w"):
            pass
        os.chmod(path, 0o664)
        self.server.write_list("channels", "https://a\n")
        self.assertEqual(os.stat(path).st_mode & 0o777, 0o664)


class RequestTests(ServerTestCase):
    def start(self, timeout=None):
        if timeout is not None:
            self.server.Handler.timeout = timeout
        httpd = ThreadingHTTPServer(("127.0.0.1", 0), self.server.Handler)
        threading.Thread(target=httpd.serve_forever, daemon=True).start()
        self.addCleanup(httpd.server_close)
        self.addCleanup(httpd.shutdown)
        return httpd.server_address[1]

    def raw(self, port, request, wait=5, half_close=False):
        with socket.create_connection(("127.0.0.1", port), timeout=wait) as s:
            s.sendall(request)
            if half_close:
                s.shutdown(socket.SHUT_WR)
            data = b""
            try:
                while True:
                    chunk = s.recv(4096)
                    if not chunk:
                        break
                    data += chunk
            except socket.timeout:
                return None
            return data

    def test_unicode_digits_in_content_length_get_400(self):
        port = self.start()
        for value in ("²", "³", "1_0"):
            reply = self.raw(
                port,
                f"POST /save HTTP/1.0\r\nHost: localhost\r\nContent-Length: {value}\r\n\r\n".encode("latin-1"),
            )
            self.assertIsNotNone(reply, value)
            self.assertTrue(reply.startswith(b"HTTP/1.0 400"), (value, reply[:40]))

    def test_handler_has_a_read_timeout(self):
        self.assertIsNotNone(self.server.Handler.timeout)
        self.assertLessEqual(self.server.Handler.timeout, 60)

    def test_stalled_body_is_dropped(self):
        port = self.start(timeout=0.5)
        started = time.monotonic()
        reply = self.raw(
            port,
            b"POST /save HTTP/1.0\r\nHost: localhost\r\nContent-Length: 1048576\r\n\r\nchannels=x",
            wait=5,
        )
        self.assertIsNotNone(reply, "the connection was held open")
        self.assertLess(time.monotonic() - started, 4)
        self.assertEqual(os.listdir(self.lists), [], "a cut-off body must not be saved")

    def test_short_body_does_not_change_a_list(self):
        self.server.write_list("channels", "https://old\n")
        port = self.start(timeout=5)
        self.raw(
            port,
            b"POST /save HTTP/1.0\r\nHost: localhost\r\nContent-Length: 100\r\n\r\nchannels=x",
            half_close=True,
        )
        self.assertEqual(self.server.read_list("channels"), "https://old\n")

    def post(self, port, path, body, extra=""):
        reply = self.raw(
            port,
            (f"POST {path} HTTP/1.0\r\nHost: localhost\r\nContent-Length: {len(body)}\r\n{extra}\r\n").encode()
            + body,
        )
        self.assertIsNotNone(reply)
        return reply

    def test_only_save_saves_the_lists(self):
        port = self.start(timeout=5)
        for path in ("/", "/download/x", "/other", "/save/../x"):
            reply = self.post(port, path, b"channels=https://x")
            self.assertTrue(reply.startswith(b"HTTP/1.0 404"), (path, reply[:40]))
        self.assertEqual(os.listdir(self.lists), [])
        reply = self.post(port, "/save", b"channels=https://x")
        self.assertTrue(reply.startswith(b"HTTP/1.0 303"), reply[:40])
        self.assertEqual(self.server.read_list("channels"), "https://x\n")

    def test_failed_save_gets_an_answer(self):
        port = self.start(timeout=5)
        with mock.patch.object(self.server, "write_list", side_effect=OSError(28, "No space left on device")):
            reply = self.post(port, "/save", b"channels=https://x")
        self.assertTrue(reply.startswith(b"HTTP/1.0 500"), reply[:40])
        self.assertIn(b"could not save", reply)

    def test_failed_download_start_gets_an_answer(self):
        port = self.start(timeout=5)
        with mock.patch.object(self.server, "start_download", side_effect=OSError(13, "Permission denied")):
            reply = self.post(port, "/download", b"url=https://example.com/v&profile=channels")
        self.assertTrue(reply.startswith(b"HTTP/1.0 500"), reply[:40])

    def test_nul_byte_in_the_url_is_refused(self):
        port = self.start(timeout=5)
        reply = self.post(port, "/download", b"url=https://example.com/a%00b&profile=channels")
        self.assertTrue(reply.startswith(b"HTTP/1.0 303"), reply[:40])
        self.assertIn(b"invalid=1", reply)


class CheckTests(ServerTestCase):
    def test_url_re(self):
        for url in ("https://example.com/watch?v=1", "http://a", "HTTPS://EXAMPLE.COM"):
            self.assertTrue(self.server.URL_RE.match(url), url)
        for url in ("--exec=id", "-x", "ftp://a", "https://", "https://a b", "https://a\nb",
                    "https://a\x00b", "https://a\x7f", " https://a", "file:///etc/passwd"):
            self.assertFalse(self.server.URL_RE.match(url), repr(url))

    def test_host_allowed(self):
        for host in ("", "localhost", "localhost:8083", "tower", "tower:8083", "TOWER.local", "nas.lan:1",
                     "x.home.arpa", "x.internal", "192.168.1.5", "192.168.1.5:8083", "[::1]:8083", "[fe80::1]",
                     "tower.local."):
            self.assertTrue(self.server.host_allowed(host), host)
        for host in ("attacker.example", "attacker.example:8083", "evil.com.", "local.evil.com",
                     "lan.example.org"):
            self.assertFalse(self.server.host_allowed(host), host)

    def test_allowed_hosts_setting(self):
        with mock.patch.dict(os.environ, {"TDLD_ALLOWED_HOSTS": " TDLD.Example.com. , other.example "}):
            server = load_server(self.lists, self.logs, self.locks)
        self.assertTrue(server.host_allowed("tdld.example.com:443"))
        self.assertTrue(server.host_allowed("other.example"))
        self.assertFalse(server.host_allowed("example.com"))

    def test_same_origin(self):
        same = self.server.same_origin
        self.assertTrue(same({}))
        self.assertTrue(same({"Sec-Fetch-Site": "same-origin"}))
        self.assertTrue(same({"Sec-Fetch-Site": "none"}))
        self.assertFalse(same({"Sec-Fetch-Site": "cross-site"}))
        self.assertFalse(same({"Sec-Fetch-Site": "same-site"}))
        # Sec-Fetch-Site wins over a matching Origin.
        self.assertFalse(same({"Sec-Fetch-Site": "cross-site", "Origin": "http://tower:8083", "Host": "tower:8083"}))
        self.assertTrue(same({"Origin": "http://tower:8083", "Host": "tower:8083"}))
        self.assertTrue(same({"Origin": "https://tdld.example.com", "Host": "tdld:8083",
                              "X-Forwarded-Host": "tdld.example.com"}))
        self.assertFalse(same({"Origin": "https://evil.example", "Host": "tower:8083"}))
        self.assertFalse(same({"Origin": "null", "Host": "tower:8083"}))


if __name__ == "__main__":
    unittest.main()
