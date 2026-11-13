pragma Singleton

import QtQuick
import Quickshell

// Weather from Open-Meteo (free, no account or key). The place is picked in
// the settings overlay and stored as name + coordinates in Settings; only
// those coordinates (and the search text while picking) are sent.
// Refreshes every 15 min while a place is set.
Singleton {
    id: root

    readonly property bool enabled: Settings.weatherCity !== ""
    readonly property string unit: Settings.weatherFahrenheit ? "°F" : "°C"

    // { temp, feels, humidity, wind, code, isDay }
    property var current: null
    // [{ date, code, max, min, rain }]  today first
    property var daily: []
    // [{ time, temp, code, rain, isDay }]  now and every 2 h up to +12 h
    property var hourly: []
    property bool loading: false
    property string error: ""
    property date updated

    // place search for the settings overlay: [{ name, region, country, lat, lon }]
    property var matches: []
    property bool searching: false

    function get(url, cb) {
        const x = new XMLHttpRequest();
        x.onreadystatechange = () => {
            if (x.readyState !== XMLHttpRequest.DONE)
                return;
            let d = null;
            try {
                d = JSON.parse(x.responseText);
            } catch (e) {}
            cb(x.status === 200 ? d : null, x.status === 0 ? "No connection" : d && d.reason ? d.reason : "HTTP " + x.status);
        };
        x.open("GET", url);
        x.send();
    }

    function refresh() {
        if (!enabled)
            return;
        loading = true;
        const q = "latitude=" + Settings.weatherLat + "&longitude=" + Settings.weatherLon + "&current=temperature_2m,apparent_temperature,relative_humidity_2m,weather_code,wind_speed_10m,is_day" + "&daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max" + "&hourly=temperature_2m,weather_code,precipitation_probability,is_day&forecast_hours=13&forecast_days=5" + "&timezone=auto" + (Settings.weatherFahrenheit ? "&temperature_unit=fahrenheit&wind_speed_unit=mph" : "");
        get("https://api.open-meteo.com/v1/forecast?" + q, (d, err) => {
            loading = false;
            if (!d || !d.current) {
                error = err;
                return;
            }
            error = "";
            const c = d.current;
            current = {
                temp: c.temperature_2m,
                feels: c.apparent_temperature,
                humidity: c.relative_humidity_2m,
                wind: c.wind_speed_10m,
                windUnit: d.current_units ? d.current_units.wind_speed_10m : "km/h",
                code: c.weather_code,
                isDay: c.is_day === 1
            };
            daily = d.daily.time.map((t, i) => ({
                        date: t,
                        code: d.daily.weather_code[i],
                        max: d.daily.temperature_2m_max[i],
                        min: d.daily.temperature_2m_min[i],
                        rain: d.daily.precipitation_probability_max[i]
                    }));
            // now, +2 h, +4 h … +12 h: 7 columns that always fit (no scrolling)
            hourly = d.hourly.time.map((t, i) => ({
                        time: t,
                        temp: d.hourly.temperature_2m[i],
                        code: d.hourly.weather_code[i],
                        rain: d.hourly.precipitation_probability[i],
                        isDay: d.hourly.is_day[i] === 1
                    })).filter((h, i) => i % 2 === 0);
            updated = new Date();
        });
    }

    function search(text) {
        const q = text.trim();
        if (q.length < 2) {
            matches = [];
            return;
        }
        searching = true;
        get("https://geocoding-api.open-meteo.com/v1/search?count=5&language=en&format=json&name=" + encodeURIComponent(q), (d, err) => {
            searching = false;
            matches = ((d && d.results) || []).map(r => ({
                        name: r.name,
                        region: r.admin1 || "",
                        country: r.country || "",
                        lat: r.latitude,
                        lon: r.longitude
                    }));
        });
    }
    function choose(m) {
        Settings.weatherPlace = {
            name: m.name,
            lat: m.lat,
            lon: m.lon
        };
        matches = [];
    }
    function clear() {
        Settings.weatherPlace = {};
        current = null;
        daily = [];
        hourly = [];
    }

    // WMO weather code → label / Material Design glyph
    function label(code) {
        if (code === 0)
            return "Clear";
        if (code === 1)
            return "Mostly clear";
        if (code === 2)
            return "Partly cloudy";
        if (code === 3)
            return "Overcast";
        if (code === 45 || code === 48)
            return "Fog";
        if (code >= 51 && code <= 57)
            return "Drizzle";
        if (code >= 61 && code <= 67)
            return code >= 66 ? "Freezing rain" : code === 65 ? "Heavy rain" : "Rain";
        if (code >= 71 && code <= 77)
            return "Snow";
        if (code >= 80 && code <= 82)
            return "Showers";
        if (code === 85 || code === 86)
            return "Snow showers";
        if (code >= 95)
            return "Thunderstorm";
        return "—";
    }
    function glyph(code, day) {
        const g = c => String.fromCodePoint(c);
        if (code === 0)
            return day === false ? g(0xF0594) : g(0xF0599);           // night / sunny
        if (code === 1 || code === 2)
            return day === false ? g(0xF0F31) : g(0xF0595);           // partly cloudy
        if (code === 3)
            return g(0xF0590);                                        // cloudy
        if (code === 45 || code === 48)
            return g(0xF0591);                                        // fog
        if (code >= 51 && code <= 67)
            return code === 65 || code === 82 ? g(0xF0596) : g(0xF0597);   // pouring / rainy
        if (code >= 80 && code <= 82)
            return code === 82 ? g(0xF0596) : g(0xF0597);
        if ((code >= 71 && code <= 77) || code === 85 || code === 86)
            return g(0xF0598);                                        // snowy
        if (code >= 95)
            return g(0xF067E);                                        // lightning-rainy
        return g(0xF0590);
    }
    function deg(v) {
        return v === undefined || v === null ? "–" : Math.round(v) + "°";
    }

    Timer {
        interval: 15 * 60 * 1000
        running: root.enabled
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }
    Connections {
        target: Settings
        function onWeatherPlaceChanged() {
            root.refresh();
        }
        function onWeatherFahrenheitChanged() {
            root.refresh();
        }
    }
}
