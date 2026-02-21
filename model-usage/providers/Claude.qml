import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root
    visible: false

    property string providerId: "claude"
    property string providerName: "Claude Code"
    property string providerIcon: "ai"
    property bool enabled: false
    property bool ready: false
    property string usageStatusText: ""

    property real rateLimitPercent: -1
    property string rateLimitLabel: "Weekly (7-day)"
    property string rateLimitResetAt: ""
    property real secondaryRateLimitPercent: -1
    property string secondaryRateLimitLabel: "Session (5-hour)"
    property string secondaryRateLimitResetAt: ""

    property int todayPrompts: 0
    property int todaySessions: 0
    property int todayTotalTokens: 0
    property var todayTokensByModel: ({})

    property var recentDays: []
    property int totalPrompts: 0
    property int totalSessions: 0
    property var modelUsage: ({})
    property var dailyActivity: []

    property string tierLabel: ""

    property string oauthAccessToken: ""
    property string oauthRefreshToken: ""
    property double oauthExpiresAtMs: 0
    property double oauthRefreshedAtMs: 0
    property string authMode: "none"
    property string subscriptionType: ""
    property string rateLimitTier: ""
    property bool hasAuthoritativeRateLimit: false
    property bool oauthRefreshInFlight: false
    property var oauthRefreshCallbacks: []
    property int oauthExpirySkewMs: 60 * 1000
    property string oauthClientId: "9d1c250a-e61b-44d9-88ed-5944d1962f5e"
    property var oauthTokenUrls: providerSettings?.oauthTokenUrls ?? ["https://claude.ai/v1/oauth/token", "https://platform.claude.com/v1/oauth/token"]

    property var providerSettings: ({})

    function resolvePath(p) {
        if (p && p.startsWith("~"))
            return (Quickshell.env("HOME") ?? "/home") + p.substring(1);
        return p;
    }

    FileView {
        id: statsFile
        path: root.resolvePath(root.providerSettings?.statsPath ?? "~/.claude/stats-cache.json")
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.parseStats(text())
        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound)
                console.warn("[model-usage/claude] stats-cache.json not found at", statsFile.path);
        }
    }

    FileView {
        id: historyFile
        path: root.resolvePath("~/.claude/history.jsonl")
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.parseHistory(text())
        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound)
                console.warn("[model-usage/claude] history.jsonl not found");
        }
    }

    FileView {
        id: credentialsFile
        path: root.resolvePath(root.providerSettings?.credentialsPath ?? "~/.claude/.credentials.json")
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.parseCredentials(text())
        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound)
                console.warn("[model-usage/claude] credentials.json not found at", credentialsFile.path);
        }
    }

    Timer {
        interval: 5 * 60 * 1000
        running: root.enabled && root.oauthAccessToken !== ""
        repeat: true
        onTriggered: root.probeRateLimits()
    }

    function localDateString() {
        const now = new Date();
        const y = now.getFullYear();
        const m = String(now.getMonth() + 1).padStart(2, "0");
        const d = String(now.getDate()).padStart(2, "0");
        return y + "-" + m + "-" + d;
    }

    function parseStats(content) {
        try {
            const data = JSON.parse(content);
            const today = localDateString();

            const dailyModelTokens = data.dailyModelTokens ?? [];
            const todayTokenEntry = dailyModelTokens.find(d => d.date === today);
            root.todayTokensByModel = todayTokenEntry?.tokensByModel ?? {};

            let tokenSum = 0;
            const toks = root.todayTokensByModel;
            for (const k in toks)
                tokenSum += toks[k];
            root.todayTotalTokens = tokenSum;

            root.dailyActivity = data.dailyActivity ?? [];
            root.recentDays = root.dailyActivity.slice(-7);
            root.modelUsage = data.modelUsage ?? {};
            root.totalPrompts = data.totalMessages ?? 0;
            root.totalSessions = data.totalSessions ?? 0;
            root.ready = true;
        } catch (e) {
            console.warn("[model-usage/claude] Failed to parse stats-cache.json:", e);
        }
    }

    function parseHistory(content) {
        try {
            const now = new Date();
            const startOfDay = new Date(now.getFullYear(), now.getMonth(), now.getDate()).getTime();
            const lines = content.split("\n");
            let prompts = 0;
            const sessions = {};

            for (let i = lines.length - 1; i >= 0; i--) {
                const line = lines[i].trim();
                if (!line)
                    continue;
                try {
                    const entry = JSON.parse(line);
                    if ((entry.timestamp ?? 0) < startOfDay)
                        break;
                    prompts++;
                    if (entry.sessionId)
                        sessions[entry.sessionId] = true;
                } catch (e) {
                    continue;
                }
            }

            root.todayPrompts = prompts;
            root.todaySessions = Object.keys(sessions).length;
        } catch (e) {
            console.warn("[model-usage/claude] Failed to parse history.jsonl:", e);
        }
    }

    function parseCredentials(content) {
        try {
            const data = JSON.parse(content);
            const oauth = data.claudeAiOauth ?? {};
            const fileAccessToken = oauth.accessToken ?? "";
            const fileRefreshToken = oauth.refreshToken ?? "";
            const fileExpiresAtMs = root.normalizeExpiresAtMs(oauth.expiresAt);
            const fileHasOAuth = (fileAccessToken !== "" || fileRefreshToken !== "");
            const nowMs = Date.now();

            const keepInMemoryToken = (fileHasOAuth && root.authMode === "oauth" && root.oauthAccessToken !== "" && ((root.oauthExpiresAtMs > (nowMs + root.oauthExpirySkewMs) && (fileExpiresAtMs <= 0 || fileExpiresAtMs < root.oauthExpiresAtMs)) || (root.oauthRefreshedAtMs > 0 && root.oauthRefreshedAtMs > (nowMs - (6 * 60 * 60 * 1000)) && (fileExpiresAtMs <= 0 || fileExpiresAtMs < (nowMs + root.oauthExpirySkewMs)))));

            if (!keepInMemoryToken) {
                const tokenChanged = (root.oauthAccessToken !== fileAccessToken || root.oauthRefreshToken !== fileRefreshToken || root.oauthExpiresAtMs !== fileExpiresAtMs);
                root.oauthAccessToken = fileAccessToken;
                root.oauthRefreshToken = fileRefreshToken;
                root.oauthExpiresAtMs = fileExpiresAtMs;
                root.oauthRefreshedAtMs = 0;
                if (tokenChanged)
                    root.clearAuthoritativeRateLimits();
            }
            root.authMode = (fileHasOAuth || keepInMemoryToken) ? "oauth" : "none";

            root.subscriptionType = oauth.subscriptionType ?? "";
            root.rateLimitTier = oauth.rateLimitTier ?? "";
            root.tierLabel = formatTier();

            if (root.oauthAccessToken) {
                root.clearUsageStatus();
                root.probeRateLimits();
            } else {
                root.setReauthRequired();
                root.clearAuthoritativeRateLimits();
            }
        } catch (e) {
            console.warn("[model-usage/claude] Failed to parse credentials.json:", e);
            root.setReauthRequired();
            root.clearAuthoritativeRateLimits();
        }
    }

    function formatTier() {
        if (!root.rateLimitTier)
            return root.subscriptionType || "";
        const match = root.rateLimitTier.match(/max_(\d+x)/i);
        if (match)
            return "Max " + match[1];
        if (root.subscriptionType)
            return root.subscriptionType.charAt(0).toUpperCase() + root.subscriptionType.slice(1);
        return "";
    }

    function normalizeExpiresAtMs(value) {
        const n = Number(value ?? 0);
        return (isFinite(n) && n > 0) ? n : 0;
    }

    function oauthTokenExpiresSoon() {
        if (!root.oauthAccessToken)
            return true;
        if (!root.oauthExpiresAtMs || !(root.oauthExpiresAtMs > 0))
            return false;
        return root.oauthExpiresAtMs <= (Date.now() + root.oauthExpirySkewMs);
    }

    function clearAuthoritativeRateLimits() {
        root.hasAuthoritativeRateLimit = false;
        root.rateLimitPercent = -1;
        root.rateLimitLabel = "Weekly (7-day)";
        root.rateLimitResetAt = "";
        root.secondaryRateLimitPercent = -1;
        root.secondaryRateLimitLabel = "Session (5-hour)";
        root.secondaryRateLimitResetAt = "";
    }

    function setReauthRequired() {
        root.usageStatusText = "Reauth required";
    }

    function clearUsageStatus() {
        root.usageStatusText = "";
    }

    function parseNumber(value) {
        if (value === null || value === undefined)
            return NaN;
        return parseFloat(String(value).trim().replace("%", ""));
    }

    function normalizeUtilization(value) {
        const n = parseNumber(value);
        if (!(n >= 0))
            return -1;
        if (n > 1)
            return Math.min(1, n / 100);
        return Math.min(1, n);
    }

    function normalizeResetAt(value) {
        if (value === null || value === undefined)
            return "";
        const raw = String(value).trim();
        if (raw === "")
            return "";
        if (/^\d+$/.test(raw)) {
            let ts = parseInt(raw, 10);
            if (ts < 1e12)
                ts = ts * 1000;
            const d = new Date(ts);
            if (!isNaN(d.getTime()))
                return d.toISOString();
        }
        const parsed = new Date(raw);
        if (!isNaN(parsed.getTime()))
            return parsed.toISOString();
        return raw;
    }

    function oauthUsageBucket(payload, key) {
        const bucket = payload?.[key];
        if (bucket && typeof bucket === "object")
            return bucket;
        return null;
    }

    function finishOAuthRefresh(success) {
        root.oauthRefreshInFlight = false;
        const callbacks = root.oauthRefreshCallbacks.slice();
        root.oauthRefreshCallbacks = [];
        for (let i = 0; i < callbacks.length; i++) {
            try {
                callbacks[i](success);
            } catch (e) {}
        }
    }

    function refreshOAuthToken(onDone) {
        if (onDone)
            root.oauthRefreshCallbacks.push(onDone);
        if (root.oauthRefreshInFlight)
            return;

        if (!root.oauthRefreshToken) {
            root.setReauthRequired();
            root.finishOAuthRefresh(false);
            return;
        }

        root.oauthRefreshInFlight = true;
        const urls = root.oauthTokenUrls ?? [];
        const body = "grant_type=refresh_token" + "&refresh_token=" + encodeURIComponent(root.oauthRefreshToken) + "&client_id=" + encodeURIComponent(root.oauthClientId);
        let sawInvalidGrant = false;

        function tryRefreshAt(index) {
            if (index >= urls.length) {
                if (sawInvalidGrant)
                    root.setReauthRequired();
                root.finishOAuthRefresh(false);
                return;
            }

            const url = urls[index];
            const xhr = new XMLHttpRequest();
            xhr.open("POST", url);
            xhr.setRequestHeader("Content-Type", "application/x-www-form-urlencoded");
            xhr.setRequestHeader("Accept", "application/json");
            xhr.onreadystatechange = function () {
                if (xhr.readyState !== XMLHttpRequest.DONE)
                    return;

                if (xhr.status >= 200 && xhr.status < 300) {
                    try {
                        const payload = JSON.parse(xhr.responseText ?? "{}");
                        const newAccessToken = payload.access_token ?? "";
                        if (newAccessToken === "") {
                            tryRefreshAt(index + 1);
                            return;
                        }

                        const expiresInSec = Number(payload.expires_in ?? 0);
                        const refreshedExpiresAt = (isFinite(expiresInSec) && expiresInSec > 0) ? (Date.now() + (expiresInSec * 1000)) : root.oauthExpiresAtMs;

                        root.oauthAccessToken = newAccessToken;
                        if (payload.refresh_token)
                            root.oauthRefreshToken = payload.refresh_token;
                        if (refreshedExpiresAt > 0)
                            root.oauthExpiresAtMs = refreshedExpiresAt;
                        root.oauthRefreshedAtMs = Date.now();
                        root.authMode = "oauth";

                        root.clearUsageStatus();
                        root.clearAuthoritativeRateLimits();
                        root.finishOAuthRefresh(true);
                        return;
                    } catch (e) {
                        tryRefreshAt(index + 1);
                        return;
                    }
                }

                const bodyLower = String(xhr.responseText ?? "").toLowerCase();
                if (bodyLower.indexOf("invalid_grant") >= 0)
                    sawInvalidGrant = true;

                tryRefreshAt(index + 1);
            };
            xhr.send(body);
        }

        tryRefreshAt(0);
    }

    function applyAuthoritativeRateLimits(weekly, weeklyReset, session, sessionReset, sourceLabel) {
        const weeklyNorm = root.normalizeUtilization(weekly);
        const sessionNorm = root.normalizeUtilization(session);
        if (weeklyNorm < 0 && sessionNorm < 0)
            return false;

        root.hasAuthoritativeRateLimit = true;
        root.rateLimitPercent = -1;
        root.rateLimitLabel = "Weekly (7-day)";
        root.rateLimitResetAt = "";
        root.secondaryRateLimitPercent = -1;
        root.secondaryRateLimitLabel = "Session (5-hour)";
        root.secondaryRateLimitResetAt = "";

        if (weeklyNorm >= 0)
            root.rateLimitPercent = weeklyNorm;
        if (sessionNorm >= 0)
            root.secondaryRateLimitPercent = sessionNorm;
        if (weeklyReset !== null && weeklyReset !== undefined)
            root.rateLimitResetAt = root.normalizeResetAt(weeklyReset);
        if (sessionReset !== null && sessionReset !== undefined)
            root.secondaryRateLimitResetAt = root.normalizeResetAt(sessionReset);

        if (root.rateLimitPercent < 0 && sessionNorm >= 0) {
            root.rateLimitPercent = sessionNorm;
            root.rateLimitLabel = root.secondaryRateLimitLabel;
            root.rateLimitResetAt = root.secondaryRateLimitResetAt;
        }

        if (sourceLabel)
            root.rateLimitLabel = root.rateLimitLabel + " (" + sourceLabel + ")";
        return true;
    }

    function probeOAuthUsage(allowRefresh) {
        const canRefresh = allowRefresh !== false;
        const xhr = new XMLHttpRequest();
        xhr.open("GET", "https://api.anthropic.com/api/oauth/usage");
        xhr.setRequestHeader("Authorization", "Bearer " + root.oauthAccessToken);
        xhr.setRequestHeader("anthropic-beta", "oauth-2025-04-20");
        xhr.setRequestHeader("Accept", "application/json");
        xhr.onreadystatechange = function () {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return;

            if (xhr.status >= 200 && xhr.status < 300) {
                try {
                    const payload = JSON.parse(xhr.responseText ?? "{}");
                    const weeklyBucket = root.oauthUsageBucket(payload, "seven_day_oauth_apps") || root.oauthUsageBucket(payload, "seven_day");
                    const sessionBucket = root.oauthUsageBucket(payload, "five_hour");

                    if (root.applyAuthoritativeRateLimits(weeklyBucket?.utilization, weeklyBucket?.resets_at, sessionBucket?.utilization, sessionBucket?.resets_at, "")) {
                        root.clearUsageStatus();
                        return;
                    }
                } catch (e) {
                    console.warn("[model-usage/claude] Failed to parse oauth usage response:", e);
                }
            }

            if ((xhr.status === 401 || xhr.status === 403) && canRefresh && root.oauthRefreshToken) {
                root.refreshOAuthToken(function (success) {
                    if (success)
                        root.probeOAuthUsage(false);
                    else {
                        root.setReauthRequired();
                        root.clearAuthoritativeRateLimits();
                    }
                });
                return;
            }

            if (xhr.status === 401 || xhr.status === 403)
                root.setReauthRequired();

            const headers = xhr.getAllResponseHeaders ? xhr.getAllResponseHeaders().trim() : "";
            const body = xhr.responseText ? String(xhr.responseText).slice(0, 220) : "";
            console.warn("[model-usage/claude] OAuth usage probe failed (status " + xhr.status + "): " + (headers || "<none>") + (body ? " body=" + body : ""));
            root.clearAuthoritativeRateLimits();
        };
        xhr.send();
    }

    function refresh() {
        statsFile.reload();
        historyFile.reload();
        credentialsFile.reload();
    }

    function formatResetTime(isoTimestamp) {
        if (!isoTimestamp)
            return "";
        const reset = new Date(isoTimestamp);
        const now = new Date();
        const diffMs = reset.getTime() - now.getTime();
        if (diffMs <= 0)
            return "now";
        const hours = Math.floor(diffMs / 3600000);
        const mins = Math.floor((diffMs % 3600000) / 60000);
        if (hours > 24)
            return Math.floor(hours / 24) + "d " + (hours % 24) + "h";
        if (hours > 0)
            return hours + "h " + mins + "m";
        return mins + "m";
    }

    function probeRateLimits() {
        if (!root.oauthAccessToken) {
            root.setReauthRequired();
            root.clearAuthoritativeRateLimits();
            return;
        }

        if (root.authMode !== "oauth") {
            root.setReauthRequired();
            root.clearAuthoritativeRateLimits();
            return;
        }

        if (root.oauthTokenExpiresSoon()) {
            if (root.oauthRefreshToken) {
                root.refreshOAuthToken(function (success) {
                    if (success)
                        root.probeOAuthUsage(false);
                    else {
                        root.setReauthRequired();
                        root.clearAuthoritativeRateLimits();
                    }
                });
            } else {
                root.setReauthRequired();
                root.clearAuthoritativeRateLimits();
            }
            return;
        }

        root.probeOAuthUsage(true);
    }
}
