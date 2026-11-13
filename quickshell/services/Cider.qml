pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Cider (cider.sh) Apple Music client, via its local RPC API on :10767.
// Search the Apple Music catalog or your library, then play now / next / later.
// Token: ~/.config/quickshell/cider-token if it exists (create one in Cider →
// Settings → Connectivity → Manage External Application Access), otherwise the
// first token in Cider's own spa-config.yml.
Singleton {
    id: root

    readonly property string api: "http://localhost:10767/api/v1"
    readonly property string home: Quickshell.env("HOME")

    property string token: ""
    property bool tokenRequired: true
    property bool available: false        // API answered
    property string storefront: "us"

    property string query: ""
    property bool library: false          // search your library instead of the catalog
    property bool searching: false
    property string error: ""
    // [{ kind: "songs"|"albums"|"playlists"|"artists", items: [{ id, type, href, title, subtitle, art }] }]
    property var results: []
    // drill-in (artist top songs / album tracks): { title, items } or null
    property var detail: null

    // Requests that never answer (Cider starting up / hanging) would otherwise
    // stay open forever; Qt allows ~6 connections per host, so a few of those
    // block every later request and `available` never recovers. So: every
    // request is aborted after 4 s (→ status 0 → "not reachable").
    property var pending: []
    Timer {
        interval: 1000
        running: root.pending.length > 0
        repeat: true
        onTriggered: {
            const now = Date.now();
            for (const p of root.pending.slice())
                if (now - p.t > 4000)
                    p.x.abort();
        }
    }

    function request(method, path, body, cb) {
        const x = new XMLHttpRequest();
        const entry = {
            x: x,
            t: Date.now()
        };
        pending = pending.concat([entry]);
        x.onreadystatechange = () => {
            if (x.readyState !== XMLHttpRequest.DONE)
                return;
            root.pending = root.pending.filter(p => p !== entry);
            let d = null;
            try {
                d = JSON.parse(x.responseText);
            } catch (e) {}
            if (x.status === 0) {
                root.available = false;
                cb && cb(null, "Cider isn't running (or its API is off)");
            } else if (d && d.statusCode >= 400) {
                cb && cb(null, String(d.message || d.error).split("\n")[0]);
            } else if (d && d.error) {
                cb && cb(null, d.error === "UNAUTHORIZED_APP_TOKEN" ? "Cider rejected the API token" : String(d.error));
            } else {
                root.available = true;
                cb && cb(d, "");
            }
        };
        x.open(method, api + path);
        if (token)
            x.setRequestHeader("apptoken", token);
        if (body)
            x.setRequestHeader("Content-Type", "application/json");
        x.send(body ? JSON.stringify(body) : null);
    }
    // Apple Music API call proxied through Cider (uses your account)
    function am(path, cb) {
        request("POST", "/amapi/run-v3", {
            path: path
        }, (d, err) => {
            const r = d && d.data ? d.data : null;
            if (r && r.errors && r.errors.length)
                return cb(null, r.errors[0].detail || r.errors[0].title);
            cb(r, err);
        });
    }

    function art(a, size) {
        return a && a.artwork && a.artwork.url ? a.artwork.url.replace("{w}", size).replace("{h}", size).replace("{f}", "jpg") : "";
    }
    function item(i) {
        const a = i.attributes || {};
        const kind = i.type.replace(/^library-/, "");
        let sub = "";
        if (kind === "songs")
            sub = (a.artistName || "") + (a.albumName ? "  ·  " + a.albumName : "");
        else if (kind === "albums")
            sub = (a.artistName || "") + (a.trackCount ? "  ·  " + a.trackCount + (a.trackCount === 1 ? " track" : " tracks") : "");
        else if (kind === "playlists")
            sub = a.curatorName || (a.description && a.description.short) || "Playlist";
        else
            sub = (a.genreNames || []).join(", ") || "Artist";
        return {
            id: i.id,
            type: i.type,
            kind: kind,
            href: i.href,
            title: a.name || "?",
            subtitle: sub,
            art: art(a, 80)
        };
    }

    function search(q) {
        query = q;
        detail = null;
        debounce.restart();
    }
    function runSearch() {
        const q = query.trim();
        if (!q) {
            results = [];
            searching = false;
            return;
        }
        searching = true;
        const term = encodeURIComponent(q);
        const path = library ? "/v1/me/library/search?term=" + term + "&types=library-songs,library-albums,library-playlists,library-artists&limit=5" : "/v1/catalog/" + storefront + "/search?term=" + term + "&types=songs,albums,playlists,artists&limit=5";
        const asked = q;
        am(path, (d, err) => {
            if (asked !== root.query.trim())
                return;     // a newer search is on its way
            root.searching = false;
            root.error = err;
            const r = (d && d.results) || {};
            const order = ["songs", "albums", "playlists", "artists"];
            const out = [];
            for (const k of order) {
                const block = r[k] || r["library-" + k];
                if (block && block.data && block.data.length)
                    out.push({
                        kind: k,
                        items: block.data.map(item)
                    });
            }
            root.results = out;
        });
    }

    // artist → top songs · album → tracks
    function open(it) {
        searching = true;
        const path = it.kind === "artists" ? (it.type.startsWith("library-") ? it.href + "/albums?limit=50" : "/v1/catalog/" + storefront + "/artists/" + it.id + "/view/top-songs?limit=20") : it.href + "/tracks?limit=100";
        am(path, (d, err) => {
            root.searching = false;
            root.error = err;
            if (d && d.data)
                root.detail = {
                    title: it.title,
                    parent: it,
                    items: d.data.map(item)
                };
        });
    }

    // shuffle: switch Cider's shuffle on (if off) before starting
    function play(it, shuffle) {
        const go = () => request("POST", "/playback/play-item-href", {
                href: it.href
            }, (d, err) => root.error = err);
        if (!shuffle)
            return go();
        request("GET", "/playback/shuffle-mode", null, d => {
            if (d && d.value === 0)
                request("POST", "/playback/toggle-shuffle", null, go);
            else
                go();
        });
    }
    function playNext(it) {
        request("POST", "/playback/play-next", {
            type: it.type,
            id: it.id
        }, (d, err) => root.error = err);
    }
    function playLater(it) {
        request("POST", "/playback/play-later", {
            type: it.type,
            id: it.id
        }, (d, err) => root.error = err);
    }

    // ── play / pause that never does nothing ──
    // Something loaded (playing or paused) → toggle it. Nothing loaded →
    // shuffle your Heavy Rotation mix. Cider not running → start it and
    // do the same once its API answers. Other players (browser…) just toggle.
    property bool mixing: false
    property int launchTries: 0

    function playPause(player) {
        const isCider = player && /cider/i.test(player.identity || "");
        if (player && !isCider)
            return player.togglePlaying();
        if (!player && !available) {
            launchTries = 0;
            Quickshell.execDetached(["cider"]);
            launchWait.start();
            return;
        }
        request("GET", "/playback/now-playing", null, (d, err) => {
            if (!d) {
                // API not answering: plain MPRIS toggle if the player can,
                // otherwise Cider is still starting, so wait for its API
                if (player && (player.isPlaying ? player.canPause : player.canPlay))
                    player.togglePlaying();
                else {
                    launchTries = 0;
                    launchWait.start();
                }
                return;
            }
            if (d.info && d.info.name)
                request("POST", "/playback/playpause", null, null);
            else
                playRecent();
        });
    }

    // your "Heavy Rotation" personal mix, shuffled (Cider's own shuffle on).
    // Found by name among Apple Music's personal mixes (pl.pm-…) in your
    // recommendations, so it keeps working if the id ever changes.
    // Falls back to shuffling your recently played songs.
    readonly property var mixName: /heavy rotation/i
    function playRecent() {
        if (mixing)
            return;
        mixing = true;
        am("/v1/me/recommendations?limit=30", (d, err) => {
            let mix = null;
            for (const r of (d && d.data) || []) {
                const items = (r.relationships && r.relationships.contents && r.relationships.contents.data) || [];
                mix = items.find(c => String(c.id).startsWith("pl.pm-") && root.mixName.test((c.attributes && c.attributes.name) || ""));
                if (mix)
                    break;
            }
            if (!mix) {
                mixing = false;
                return playRecentTracks();
            }
            const href = mix.href || "/v1/catalog/" + storefront + "/playlists/" + mix.id;
            request("GET", "/playback/shuffle-mode", null, sm => {
                const go = () => request("POST", "/playback/play-item-href", {
                        href: href
                    }, (r, e) => {
                        root.mixing = false;
                        if (!r)
                            root.notify("Cider couldn't start Heavy Rotation: " + e);
                    });
                if (sm && sm.value === 0)
                    request("POST", "/playback/toggle-shuffle", null, go);
                else
                    go();
            });
        });
    }

    // fallback: up to 60 recently played songs, shuffled
    function playRecentTracks() {
        if (mixing)
            return;
        mixing = true;
        const all = [];
        const page = off => am("/v1/me/recent/played/tracks?limit=30&offset=" + off, (d, err) => {
            if (d && d.data)
                for (const t of d.data)
                    if (t.type === "songs" && !all.some(x => x.id === t.id))
                        all.push(t);
            if (off === 0 && d && d.next)
                return page(30);
            startMix(all, err);
        });
        page(0);
    }

    function startMix(tracks, err) {
        if (!tracks.length) {
            mixing = false;
            notify("Couldn't load your recently played songs" + (err ? ": " + err : ""));
            return;
        }
        for (let i = tracks.length - 1; i > 0; i--) {      // Fisher–Yates
            const j = Math.floor(Math.random() * (i + 1));
            [tracks[i], tracks[j]] = [tracks[j], tracks[i]];
        }
        request("POST", "/playback/play-item-href", {
            href: tracks[0].href
        }, (d, e) => {
            if (!d) {
                mixing = false;
                notify("Cider couldn't start playback: " + e);
                return;
            }
            // queue the rest once playback has started; one at a time keeps the order
            mixQueue = tracks.slice(1);
            queueTimer.start();
        });
    }
    property var mixQueue: []
    Timer {
        id: queueTimer
        interval: 1500
        onTriggered: {
            const t = root.mixQueue.shift();
            if (!t) {
                root.mixing = false;
                return;
            }
            root.request("POST", "/playback/play-later", {
                type: "songs",
                id: t.id
            }, () => {
                queueTimer.interval = 120;
                queueTimer.start();
            });
        }
    }
    onMixingChanged: if (mixing) queueTimer.interval = 1500

    // keep `available` current while Cider starts / quits (local, cheap)
    Timer {
        interval: 5000
        running: true
        repeat: true
        onTriggered: root.ping()
    }

    // after launching Cider: wait (up to ~45 s) for its API, then play
    Timer {
        id: launchWait
        interval: 1500
        repeat: true
        onTriggered: {
            if (++root.launchTries > 30) {
                stop();
                root.notify("Cider didn't start in time");
                return;
            }
            root.request("GET", "/playback/now-playing", null, d => {
                if (!d || !launchWait.running)
                    return;
                launchWait.stop();
                if (d.info && d.info.name)
                    root.request("POST", "/playback/play", null, null);
                else
                    root.playRecent();
            });
        }
    }

    function notify(msg) {
        error = msg;
        Quickshell.execDetached(["notify-send", "-a", "Music", "-i", "cider", "Music", msg]);
    }

    function ping() {
        request("GET", "/playback/active", null, (d, err) => {
            if (d && !storefrontLoaded) {
                storefrontLoaded = true;
                am("/v1/me/storefront", s => {
                    if (s && s.data && s.data[0])
                        root.storefront = s.data[0].id;
                });
            }
        });
    }
    property bool storefrontLoaded: false

    onLibraryChanged: {
        detail = null;
        runSearch();
    }

    Timer {
        id: debounce
        interval: 300
        onTriggered: root.runSearch()
    }

    // token: own file first, then Cider's config
    FileView {
        id: ownTokenFile
        path: root.home + "/.config/quickshell/cider-token"
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            root.ownToken = true;
            root.token = text().trim();
            root.ping();
        }
    }
    property bool ownToken: false
    FileView {
        id: ciderConfig
        path: root.home + "/.config/sh.cider.genten/spa-config.yml"
        printErrors: false
        onLoaded: {
            if (root.ownToken)
                return;
            const t = text();
            const req = t.match(/apiTokensRequired:\s*(\w+)/);
            root.tokenRequired = !req || req[1] === "true";
            const m = t.match(/apiTokens:\s*\n(?:[\s\S]*?)\btoken:\s*(\S+)/);
            root.token = m ? m[1] : "";
            root.ping();
        }
    }
}
