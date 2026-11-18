/*
 *  waypoint.js
 *  Waypoint
 *
 *  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
 *  Copyright © 2026 Yousef Mohamed. MIT License.
 *
 *  Additions to the DocC site, linked from every page by scripts/build-docs.sh:
 *  - a sun and moon toggle in the navigation bar. It drives DocC's own color scheme setting
 *    (the Light/Dark/Auto picker in the footer, which waypoint.css hides), so DocC keeps
 *    remembering the choice;
 *  - a link from the mark and name in the navigation bar to the site's main page;
 *  - a sidebar the reader can resize by dragging its edge, remembered between visits.
 */
(function () {
    "use strict";

    var SUN = '<svg viewBox="0 0 24 24" aria-hidden="true"><circle cx="12" cy="12" r="4.2"/>' +
        '<path d="M12 2.5v2.2M12 19.3v2.2M2.5 12h2.2M19.3 12h2.2M5.3 5.3l1.55 1.55M17.15 17.15l1.55 1.55M5.3 18.7l1.55-1.55M17.15 6.85l1.55-1.55"/></svg>';
    var MOON = '<svg viewBox="0 0 24 24" aria-hidden="true">' +
        '<path d="M20.2 14.6A8.3 8.3 0 0 1 9.4 3.8a8.3 8.3 0 1 0 10.8 10.8z"/></svg>';
    var darkQuery = window.matchMedia("(prefers-color-scheme: dark)");

    function currentScheme() {
        var setting = document.body.getAttribute("data-color-scheme") || "auto";

        if (setting === "auto") {
            return darkQuery.matches ? "dark" : "light";
        }

        return setting;
    }

    function choose(scheme) {
        var input = document.querySelector('.color-scheme-toggle input[value="' + scheme + '"]');

        if (input) {
            input.click();
        }
    }

    function render(button) {
        var isDark = currentScheme() === "dark";

        button.innerHTML = '<span class="wp-theme-icon wp-theme-sun">' + SUN + '</span>' +
            '<span class="wp-theme-icon wp-theme-moon">' + MOON + '</span>';
        button.setAttribute("data-scheme", isDark ? "dark" : "light");
        button.setAttribute("aria-label", isDark ? "Switch to light mode" : "Switch to dark mode");
        button.title = button.getAttribute("aria-label");
    }

    function toggle(event) {
        var button = event.currentTarget;
        var next = currentScheme() === "dark" ? "light" : "dark";

        choose(next);
        button.setAttribute("data-scheme", next);
        button.setAttribute("aria-label", next === "dark" ? "Switch to light mode" : "Switch to dark mode");
        button.title = button.getAttribute("aria-label");
    }

    function install() {
        var bar = document.querySelector(".nav-content");

        if (!bar || bar.querySelector(".wp-theme-toggle")) {
            return;
        }

        var button = document.createElement("button");

        button.type = "button";
        button.className = "wp-theme-toggle";
        button.addEventListener("click", toggle);
        render(button);
        bar.insertBefore(button, bar.querySelector(".nav-actions"));
    }

    function refresh() {
        var button = document.querySelector(".wp-theme-toggle");

        if (button) {
            button.setAttribute("data-scheme", currentScheme());
        }
    }

    function installHomeLink() {
        var title = document.querySelector(".nav-content .nav-title");

        if (!title || title.querySelector(".wp-home-link")) {
            return;
        }

        var link = document.createElement("a");

        link.className = "wp-home-link";
        link.href = "/";
        link.setAttribute("aria-label", "Waypoint home");
        title.appendChild(link);
    }

    // Sidebar width. DocC keeps the sidebar between 30% and 40% of the window, so waypoint.css
    // sets the width from --wp-sidebar-width and this drag replaces DocC's own.
    var WIDTH_KEY = "waypoint.sidebarWidth";
    var DEFAULT_WIDTH = 280;
    var MIN_WIDTH = 220;

    function maxWidth() {
        return Math.max(MIN_WIDTH, Math.min(560, Math.round(window.innerWidth * 0.45)));
    }

    function clampWidth(width) {
        return Math.min(Math.max(Math.round(width), MIN_WIDTH), maxWidth());
    }

    function applyWidth(width) {
        document.documentElement.style.setProperty("--wp-sidebar-width", width + "px");
    }

    function savedWidth() {
        try {
            var value = parseInt(window.localStorage.getItem(WIDTH_KEY), 10);

            return isNaN(value) ? DEFAULT_WIDTH : clampWidth(value);
        } catch (error) {
            return DEFAULT_WIDTH;
        }
    }

    function saveWidth(width) {
        try {
            window.localStorage.setItem(WIDTH_KEY, String(width));
        } catch (error) {
            // Storage can be off, such as in a private window; the width then lasts for this page.
        }
    }

    function pointerX(event) {
        return event.touches ? event.touches[0].clientX : event.clientX;
    }

    function startResize(event) {
        var aside = document.querySelector(".sidebar .aside");

        if (!aside) {
            return;
        }

        // Keep DocC's own drag from running; it would clamp the width to its own range.
        event.stopImmediatePropagation();
        event.preventDefault();

        var left = aside.getBoundingClientRect().left;
        var width = savedWidth();

        function move(moveEvent) {
            width = clampWidth(pointerX(moveEvent) - left);
            applyWidth(width);
        }

        function end() {
            document.body.classList.remove("wp-resizing");
            document.removeEventListener("mousemove", move);
            document.removeEventListener("touchmove", move);
            document.removeEventListener("mouseup", end);
            document.removeEventListener("touchend", end);
            saveWidth(width);
        }

        document.body.classList.add("wp-resizing");
        document.addEventListener("mousemove", move);
        document.addEventListener("touchmove", move, {
            passive: true
        });
        document.addEventListener("mouseup", end);
        document.addEventListener("touchend", end);
    }

    function handleFor(event) {
        return event.target.closest && event.target.closest(".sidebar .resize-handle");
    }

    function onPress(event) {
        if (handleFor(event)) {
            startResize(event);
        }
    }

    function onDoubleClick(event) {
        if (handleFor(event)) {
            applyWidth(DEFAULT_WIDTH);
            saveWidth(DEFAULT_WIDTH);
        }
    }

    function installAll() {
        install();
        installHomeLink();
    }

    applyWidth(savedWidth());
    document.addEventListener("mousedown", onPress, true);
    document.addEventListener("touchstart", onPress, {
        capture: true,
        passive: false
    });
    document.addEventListener("dblclick", onDoubleClick, true);

    // DocC renders the page after load and redraws the bar on navigation, so watch for it.
    new MutationObserver(installAll).observe(document.documentElement, {
        childList: true,
        subtree: true
    });
    darkQuery.addEventListener("change", refresh);
    document.addEventListener("DOMContentLoaded", installAll);
})();
