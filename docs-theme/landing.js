//
//  landing.js
//  Waypoint
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//
//  Motion for the documentation landing page, with GSAP (js/vendor/gsap). The arrow travels the
//  orbit stop by stop and draws the trail behind it, the star lights up when it arrives, the
//  stars drift with the pointer and the scroll, and the journey replays on the way back up.
//  With reduced motion, or without GSAP, the page shows the finished mark and stays still.
//

(function () {
    "use strict";

    var root = document.documentElement;
    var hero = document.querySelector("header.hero");

    if (!hero) {
        return;
    }

    scatterStars(hero.querySelector(".starfield"));

    if (!window.gsap || !window.ScrollTrigger) {
        root.classList.remove("motion");
        return;
    }

    var gsap = window.gsap;

    gsap.registerPlugin(window.ScrollTrigger);

    // Mobile browsers resize the viewport as their toolbars show and hide; that must not
    // refresh the scroll animations or replay the journey.
    window.ScrollTrigger.config({ ignoreMobileResize: true });

    var media = gsap.matchMedia();

    media.add("(prefers-reduced-motion: no-preference)", function () {
        root.classList.add("motion");
        splitWords(hero.querySelector("h1"));

        var mark = createMark();
        var journey = buildJourney(mark);
        var loops = idle(mark);

        // The loops move the same parts as the journey, so they wait for it to end.
        journey.eventCallback("onComplete", function () {
            loops.forEach(function (loop) {
                loop.restart();
            });
        });

        introduceText();
        journey.play(0);
        followPointer(mark);
        followScroll(mark, function replay() {
            loops.forEach(function (loop) {
                loop.pause(0);
            });
            journey.restart();
        });
        shootStars();

        return function () {
            root.classList.remove("motion");
        };
    });

    media.add("(prefers-reduced-motion: reduce)", function () {
        root.classList.remove("motion");
    });

    // Scatters the sky: small dots on the far layer, a few sparkles in the mark's star shape on
    // the near one. A fixed seed keeps the sky the same on every visit.
    function scatterStars(field) {
        if (!field) {
            return;
        }

        var far = field.querySelector(".far");
        var near = field.querySelector(".near");
        var seed = 7;

        function random() {
            seed = (seed * 16807) % 2147483647;
            return (seed - 1) / 2147483646;
        }

        var sparkle = '<svg viewBox="-6 -6 12 12"><path d="M0 -5.5 Q1.32 -1.32 5.5 0 Q1.32 1.32 0 ' +
            '5.5 Q-1.32 1.32 -5.5 0 Q-1.32 -1.32 0 -5.5Z" fill="#EEF0FF"/></svg>';

        for (var index = 0; index < 110; index += 1) {
            var dot = document.createElement("span");
            var size = random() < 0.85 ? 1 + random() * 1.2 : 2 + random() * 1.2;

            dot.className = "dot";
            dot.style.left = (random() * 100).toFixed(2) + "%";
            dot.style.top = (random() * 100).toFixed(2) + "%";
            dot.style.width = size.toFixed(1) + "px";
            dot.style.height = size.toFixed(1) + "px";
            dot.style.setProperty("--duration", (2.5 + random() * 4).toFixed(2) + "s");
            dot.style.setProperty("--delay", (-random() * 6).toFixed(2) + "s");
            dot.style.setProperty("--high", (0.5 + random() * 0.5).toFixed(2));
            far.appendChild(dot);
        }

        for (var star = 0; star < 9; star += 1) {
            var shape = document.createElement("span");

            shape.className = "sparkle";
            shape.innerHTML = sparkle;
            shape.style.left = (4 + random() * 92).toFixed(2) + "%";
            shape.style.top = (6 + random() * 84).toFixed(2) + "%";
            shape.style.setProperty("--size", (8 + random() * 10).toFixed(0) + "px");
            near.appendChild(shape);
        }
    }

    // Wraps each word of the headline, keeping the highlighted words inside their <em>, so the
    // words can rise in one after another.
    function splitWords(heading) {
        if (!heading || heading.querySelector(".word")) {
            return;
        }

        heading.setAttribute("aria-label", heading.textContent.trim());

        Array.prototype.slice.call(heading.childNodes).forEach(function wrap(node) {
            if (node.nodeType === Node.ELEMENT_NODE) {
                Array.prototype.slice.call(node.childNodes).forEach(wrap);
                return;
            }

            if (node.nodeType !== Node.TEXT_NODE || !node.textContent.trim()) {
                return;
            }

            var fragment = document.createDocumentFragment();

            node.textContent.split(/(\s+)/).forEach(function (part) {
                if (!part) {
                    return;
                }

                if (/^\s+$/.test(part)) {
                    fragment.appendChild(document.createTextNode(part));
                    return;
                }

                var word = document.createElement("span");

                word.className = "word";
                word.setAttribute("aria-hidden", "true");
                word.textContent = part;
                fragment.appendChild(word);
            });

            node.parentNode.replaceChild(fragment, node);
        });
    }

    function introduceText() {
        var timeline = gsap.timeline({ defaults: { ease: "power3.out" } });

        timeline
            .set(".hero-body > *", { visibility: "visible" })
            .from(".topbar", { autoAlpha: 0, y: -12, duration: 0.6 })
            .from("h1 .word", { autoAlpha: 0, yPercent: 60, rotate: 4, duration: 0.8, stagger: 0.07 }, 0.1)
            .from(".lede", { autoAlpha: 0, y: 18, duration: 0.7 }, 0.55)
            .from(".actions .button", { autoAlpha: 0, y: 16, duration: 0.6, stagger: 0.1 }, 0.75)
            .fromTo(".scroll-cue", { autoAlpha: 0, y: -8 }, { autoAlpha: 1, y: 0, duration: 0.6 }, 1.6);
    }

    // The mark's parts move by their SVG attributes only (transform strings, radii, dash
    // offsets), never by CSS transforms or box-based origins, which WebKit draws unevenly on
    // SVG. Each part keeps its state in a plain object, and `draw` writes it out.
    function createMark() {
        var svg = hero.querySelector(".orbit");
        var center = 32;
        var radius = 22;
        var parts = {
            ring: svg.querySelector(".ring"),
            planet: svg.querySelector(".planet"),
            trail: svg.querySelector(".trail"),
            stops: Array.prototype.slice.call(svg.querySelectorAll(".stop")),
            ripples: Array.prototype.slice.call(svg.querySelectorAll(".ripple")),
            pulse: svg.querySelector(".pulse"),
            arrowGroup: svg.querySelector(".arrow-g"),
            arrow: svg.querySelector(".arrow"),
            star: svg.querySelector(".star"),
            glowGroup: svg.querySelector(".glow"),
            glow: svg.querySelector(".glow circle"),
            tilt: svg.querySelector(".orbit-scroll"),
            drift: svg.querySelector(".orbit-drift")
        };
        var state = {
            arrow: { angle: 135, scale: 0.55, nudge: 0, opacity: 0, trail: true },
            star: { scale: 1, rotation: 0 },
            tilt: { y: 0, rotation: 0, scale: 1 },
            drift: { x: 0, y: 0 },
            pulse: { angle: 135 }
        };

        // A point on the orbit; angles grow clockwise on screen, 270 is the top.
        function onOrbit(angle) {
            var radians = angle * Math.PI / 180;

            return [center + radius * Math.cos(radians), center + radius * Math.sin(radians)];
        }

        function round(value) {
            return Math.round(value * 1000) / 1000;
        }

        // The trail is one filled ribbon along the orbit, centred on it, that widens evenly from
        // 1.2 to 3.2 units, like the mark's three strokes but without their steps.
        function ribbon(from, to) {
            var steps = Math.max(2, Math.ceil((to - from) / 2) + 1);
            var outer = [];
            var inner = [];

            for (var index = 0; index < steps; index += 1) {
                var angle = from + (to - from) * index / (steps - 1);
                var half = 0.6 + Math.min(1, Math.max(0, (angle - 135) / 116));
                var radians = angle * Math.PI / 180;
                var cos = Math.cos(radians);
                var sin = Math.sin(radians);

                outer.push(round(center + (radius + half) * cos) + " " + round(center + (radius + half) * sin));
                inner.unshift(round(center + (radius - half) * cos) + " " + round(center + (radius - half) * sin));
            }

            return "M" + outer.join(" L") + " L" + inner.join(" L") + "Z";
        }

        // The trail ends a little behind the arrow's tail, a gap that grows with the arrow.
        function drawTrail() {
            var end = state.arrow.angle - 19 * state.arrow.scale;

            parts.trail.setAttribute("d", end > 136 ? ribbon(135, end) : "M0 0Z");
        }

        // The arrow faces along the orbit: the tangent is the angle plus a quarter turn.
        function drawArrow() {
            var arrow = state.arrow;
            var point = onOrbit(arrow.angle);

            parts.arrowGroup.setAttribute("transform", "translate(" + round(point[0]) + " " +
                round(point[1]) + ") rotate(" + round(arrow.angle + 90) + ") scale(" +
                round(arrow.scale) + ")");
            parts.arrowGroup.setAttribute("opacity", round(arrow.opacity));
            parts.arrow.setAttribute("transform", "translate(" + round(arrow.nudge) + " 0)");

            if (arrow.trail) {
                drawTrail();
            }
        }

        function drawStar() {
            parts.star.setAttribute("transform", "rotate(" + round(state.star.rotation) +
                ") scale(" + round(state.star.scale) + ")");
        }

        function drawTilt() {
            var tilt = state.tilt;

            parts.tilt.setAttribute("transform", "translate(0 " + round(tilt.y) + ") rotate(" +
                round(tilt.rotation) + " 32 32) translate(32 32) scale(" + round(tilt.scale) +
                ") translate(-32 -32)");
        }

        function drawDrift() {
            parts.drift.setAttribute("transform", "translate(" + round(state.drift.x) + " " +
                round(state.drift.y) + ")");
        }

        function drawPulse() {
            var point = onOrbit(state.pulse.angle);

            parts.pulse.setAttribute("cx", round(point[0]));
            parts.pulse.setAttribute("cy", round(point[1]));
        }

        return {
            parts: parts,
            state: state,
            drawArrow: drawArrow,
            drawStar: drawStar,
            drawTilt: drawTilt,
            drawDrift: drawDrift,
            drawPulse: drawPulse
        };
    }

    // The mark tells the navigation story: the root planet appears, the arrow is pushed from
    // stop to stop, each push leaves a thicker trail, and the arrow arrives next to the star.
    function buildJourney(mark) {
        var parts = mark.parts;
        var state = mark.state;
        var stopRadii = [1.5, 2, 2.5];
        var stopAngles = [135, 180, 225];
        var passed = [];
        var timeline = gsap.timeline({ paused: true });

        function pop(index) {
            passed[index] = true;
            gsap.to(parts.stops[index], { attr: { r: stopRadii[index] }, duration: 0.4, ease: "back.out(3)" });
            ripple(parts.ripples[index], stopRadii[index]).play();
        }

        // One smooth trip from the first stop to the top; each stop lights up as it is passed.
        function travel() {
            mark.drawArrow();
            stopAngles.forEach(function (angle, index) {
                if (!passed[index] && state.arrow.angle >= angle - 2) {
                    pop(index);
                }
            });
        }

        timeline
            .call(function () {
                passed = [];
                [parts.ring, parts.planet, parts.arrowGroup, parts.star.parentNode, parts.trail].forEach(show);
                parts.stops.forEach(show);
            }, null, 0)
            .set(parts.stops, { attr: { r: 0 } }, 0)
            .set(parts.glow, { attr: { r: 0 } }, 0)
            .set(state.arrow, {
                angle: 135,
                scale: 0.55,
                nudge: 0,
                opacity: 0,
                trail: true,
                onComplete: mark.drawArrow
            }, 0)
            .set(state.star, { scale: 0, rotation: -120, onComplete: mark.drawStar }, 0)
            .fromTo(parts.ring, { attr: { opacity: 0 } }, {
                attr: { opacity: 1 },
                duration: 1.2,
                ease: "power1.out"
            }, 0)
            .fromTo(parts.planet, { attr: { r: 0 } }, { attr: { r: 4 }, duration: 0.8, ease: "back.out(2.4)" }, 0.15);

        var at = 0.6;
        var trip = 2.1;

        timeline.to(state.arrow, { opacity: 1, duration: 0.25, onUpdate: mark.drawArrow }, at);
        timeline.to(state.arrow, {
            angle: 270,
            scale: 1,
            duration: trip,
            ease: "sine.inOut",
            onStart: function () {
                pop(0);
            },
            onUpdate: travel
        }, at);

        var arrival = at + trip - 0.15;

        timeline
            .to(state.star, {
                scale: 1,
                rotation: 0,
                duration: 0.9,
                ease: "back.out(2)",
                onUpdate: mark.drawStar
            }, arrival)
            // The glow grows by its radius, so it stays centred on the star.
            .fromTo(parts.glow, { attr: { r: 0 } }, { attr: { r: 11.5 }, duration: 0.9, ease: "power2.out" }, arrival)
            .fromTo(parts.glowGroup, { attr: { "fill-opacity": 0.5 } }, {
                attr: { "fill-opacity": 0 },
                duration: 0.9,
                ease: "power2.out"
            }, arrival)
            .to(parts.glow, { attr: { r: 5.22 }, duration: 0.6, ease: "power1.out" })
            .to(parts.glowGroup, { attr: { "fill-opacity": 0.18 }, duration: 0.6, ease: "power1.out" }, "<");

        return timeline;
    }

    function show(element) {
        element.style.visibility = "visible";
    }

    function ripple(circle, from) {
        return gsap.fromTo(circle, { attr: { r: from, opacity: 0.7 } }, {
            immediateRender: false,
            attr: { r: from * 3.2, opacity: 0 },
            duration: 0.8,
            ease: "power2.out"
        });
    }

    // Returns the loops that start when the journey ends; the rest start now. The arrow leans
    // forward, the star twinkles, the dashed way back glows softly, and now and then a
    // light runs along the trail.
    function idle(mark) {
        var parts = mark.parts;
        var state = mark.state;
        var loop = { ease: "sine.inOut", yoyo: true, repeat: -1, paused: true };
        var loops = [
            gsap.to(state.arrow, Object.assign({ nudge: 0.9, duration: 1.5, onUpdate: mark.drawArrow }, loop)),
            gsap.to(state.star, Object.assign({
                scale: 1.12,
                rotation: 12,
                duration: 1.6,
                onUpdate: mark.drawStar
            }, loop)),
            gsap.to(parts.glow, Object.assign({ attr: { r: 7 }, duration: 1.6 }, loop)),
            gsap.to(parts.glowGroup, Object.assign({ attr: { "fill-opacity": 0.36 }, duration: 1.6 }, loop)),
            gsap.to(parts.planet, Object.assign({ attr: { r: 4.3 }, duration: 2.6 }, loop))
        ];

        // The dashes stay put, each one a mirror of the trail's width at the same distance from
        // the root, so the way back glows softly instead of moving.
        gsap.fromTo(parts.ring, { attr: { "stroke-opacity": 0.45 } }, {
            attr: { "stroke-opacity": 0.7 },
            duration: 2.4,
            ease: "sine.inOut",
            yoyo: true,
            repeat: -1
        });

        // The trail ends at about 251 degrees.
        gsap.timeline({ repeat: -1, repeatDelay: 5, delay: 5 })
            .set(state.pulse, { angle: 135, onComplete: mark.drawPulse })
            .fromTo(parts.pulse, { attr: { opacity: 0 } }, { attr: { opacity: 0.9 }, duration: 0.25 })
            .to(state.pulse, { angle: 249, duration: 1.4, ease: "power1.inOut", onUpdate: mark.drawPulse }, 0)
            .to(parts.pulse, { attr: { opacity: 0 }, duration: 0.3 }, 1.15);

        gsap.utils.toArray(".starfield .sparkle").forEach(function (sparkle) {
            gsap.fromTo(sparkle, { autoAlpha: 0.15, scale: 0.6, rotation: 0 }, {
                autoAlpha: 0.95,
                scale: 1,
                rotation: 45,
                duration: gsap.utils.random(2, 4),
                ease: "sine.inOut",
                yoyo: true,
                repeat: -1,
                delay: gsap.utils.random(0, 4)
            });
        });

        return loops;
    }

    // The mark and the two star layers move a little with the pointer, the nearer ones more.
    function followPointer(mark) {
        if (!window.matchMedia("(pointer: fine)").matches) {
            return;
        }

        var layers = [
            { target: ".starfield .far", reach: 6 },
            { target: ".starfield .near", reach: 16 }
        ].map(function (layer) {
            return {
                reach: layer.reach,
                x: gsap.quickTo(layer.target, "x", { duration: 1.2, ease: "power3.out" }),
                y: gsap.quickTo(layer.target, "y", { duration: 1.2, ease: "power3.out" })
            };
        });

        hero.addEventListener("pointermove", function (event) {
            var bounds = hero.getBoundingClientRect();
            var dx = (event.clientX - bounds.left) / bounds.width - 0.5;
            var dy = (event.clientY - bounds.top) / bounds.height - 0.5;

            layers.forEach(function (layer) {
                layer.x(dx * layer.reach * 2);
                layer.y(dy * layer.reach * 2);
            });
            gsap.to(mark.state.drift, {
                x: dx * 3.2,
                y: dy * 3.2,
                duration: 1.2,
                ease: "power3.out",
                overwrite: true,
                onUpdate: mark.drawDrift
            });
        });
    }

    // Scrolling down lifts the message away, tilts the mark back and lets the sky lag behind.
    // Coming back to the top replays the journey.
    function followScroll(mark, replay) {
        var scrub = { trigger: hero, start: "top top", end: "bottom top", scrub: 0.6 };

        gsap.to(".hero-body", { y: -80, autoAlpha: 0.15, ease: "none", scrollTrigger: scrub });
        gsap.to(".scroll-cue", {
            autoAlpha: 0,
            ease: "none",
            scrollTrigger: { trigger: hero, start: "top top", end: "15% top", scrub: true }
        });
        gsap.to(mark.state.tilt, {
            y: 10,
            rotation: 14,
            scale: 0.86,
            ease: "none",
            onUpdate: mark.drawTilt,
            scrollTrigger: scrub
        });
        gsap.to(".starfield", { y: 140, ease: "none", scrollTrigger: scrub });

        window.ScrollTrigger.create({
            trigger: hero,
            start: "bottom 30%",
            onEnterBack: replay
        });
    }

    // A shooting star every few seconds, from a random point in the upper sky, while the hero
    // is on screen.
    function shootStars() {
        var field = hero.querySelector(".starfield");

        function shoot() {
            var rect = hero.getBoundingClientRect();

            if (rect.bottom > 0 && document.visibilityState === "visible") {
                var streak = document.createElement("span");
                var angle = gsap.utils.random(10, 26);
                var distance = gsap.utils.random(360, 640);
                var radians = angle * Math.PI / 180;

                streak.className = "shooting-star";
                streak.style.left = gsap.utils.random(-5, 60) + "%";
                streak.style.top = gsap.utils.random(2, 45) + "%";
                field.appendChild(streak);

                gsap.timeline({ onComplete: function () { streak.remove(); } })
                    .set(streak, { rotation: angle, autoAlpha: 0, scaleX: 0.3 })
                    .to(streak, { autoAlpha: 1, scaleX: 1, duration: 0.18, ease: "power1.out" })
                    .to(streak, {
                        x: Math.cos(radians) * distance,
                        y: Math.sin(radians) * distance,
                        duration: 1,
                        ease: "power1.in"
                    }, 0)
                    .to(streak, { autoAlpha: 0, duration: 0.35, ease: "power1.in" }, 0.65);
            }

            gsap.delayedCall(gsap.utils.random(4, 9), shoot);
        }

        gsap.delayedCall(2.6, shoot);
    }
})();
