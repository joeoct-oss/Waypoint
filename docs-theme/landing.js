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

    if (!window.gsap || !window.MotionPathPlugin || !window.ScrollTrigger) {
        root.classList.remove("motion");
        return;
    }

    var gsap = window.gsap;

    gsap.registerPlugin(window.MotionPathPlugin, window.ScrollTrigger);

    var media = gsap.matchMedia();

    media.add("(prefers-reduced-motion: no-preference)", function () {
        root.classList.add("motion");
        splitWords(hero.querySelector("h1"));

        var journey = buildJourney();
        var loops = idle();

        // The loops move the same parts as the journey, so they wait for it to end.
        journey.eventCallback("onComplete", function () {
            loops.forEach(function (loop) {
                loop.restart();
            });
        });

        introduceText();
        journey.play(0);
        followPointer();
        followScroll(function replay() {
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

    // The mark tells the navigation story: the root planet appears, the arrow is pushed from
    // stop to stop, each push leaves a thicker trail, and the arrow arrives next to the star.
    function buildJourney() {
        var orbit = ".orbit ";
        var stops = gsap.utils.toArray(orbit + ".stop");
        var trails = gsap.utils.toArray(orbit + ".trail");
        var ripples = gsap.utils.toArray(orbit + ".ripple");
        var legs = [
            "M16.44 47.56 A22 22 0 0 1 10.00 32.00",
            "M10.00 32.00 A22 22 0 0 1 16.44 16.44",
            "M16.44 16.44 A22 22 0 0 1 32.00 10.00"
        ];
        var arrowScale = [0.55, 0.72, 0.86, 1];
        var timeline = gsap.timeline({ paused: true });

        timeline
            .set([orbit + ".ring", orbit + ".planet", trails, stops, orbit + ".arrow-g", orbit + ".star-g"], {
                visibility: "visible"
            })
            // A zero-length dash still draws its round cap, so each trail hides until it starts.
            .set(trails, { strokeDasharray: 1, strokeDashoffset: 1, autoAlpha: 0 })
            .set(stops, { scale: 0, transformOrigin: "50% 50%" })
            .set(orbit + ".arrow-g", {
                autoAlpha: 0,
                x: 16.44,
                y: 47.56,
                rotation: -135,
                scale: arrowScale[0],
                transformOrigin: "50% 50%"
            })
            .set(orbit + ".star", { scale: 0, rotation: -120, transformOrigin: "50% 50%" })
            .set(orbit + ".glow circle", { attr: { r: 0 } })
            .fromTo(orbit + ".ring", { autoAlpha: 0 }, { autoAlpha: 1, duration: 1.2, ease: "power1.out" }, 0)
            .from(orbit + ".planet", {
                scale: 0,
                transformOrigin: "50% 50%",
                duration: 0.8,
                ease: "back.out(2.4)"
            }, 0.15);

        var at = 0.6;

        timeline.to(stops[0], { scale: 1, duration: 0.4, ease: "back.out(3)" }, at);
        timeline.add(ripple(ripples[0]), at);
        timeline.to(orbit + ".arrow-g", { autoAlpha: 1, duration: 0.2 }, at);

        legs.forEach(function (leg, index) {
            var start = at + 0.25 + index * 0.62;
            var duration = 0.5;

            timeline.to(orbit + ".arrow-g", {
                duration: duration,
                ease: "power2.inOut",
                scale: arrowScale[index + 1],
                motionPath: { path: leg, autoRotate: true }
            }, start);

            // The last trail ends behind the arrow's tail, so it finishes a little sooner.
            timeline.set(trails[index], { autoAlpha: 1 }, start);
            timeline.to(trails[index], {
                strokeDashoffset: 0,
                duration: index === 2 ? duration * 0.75 : duration,
                ease: "power2.inOut"
            }, start);

            if (index < 2) {
                var arrives = start + duration - 0.05;

                timeline.to(stops[index + 1], { scale: 1, duration: 0.4, ease: "back.out(3)" }, arrives);
                timeline.add(ripple(ripples[index + 1]), arrives);
            }
        });

        var arrival = at + 0.25 + 2 * 0.62 + 0.5;

        timeline
            .to(orbit + ".star", { scale: 1, rotation: 0, duration: 0.9, ease: "back.out(2)" }, arrival - 0.1)
            // The glow grows by its radius, not a scale, so it stays centred on the star.
            .fromTo(orbit + ".glow circle", { attr: { r: 0 } }, {
                attr: { r: 11.5 },
                duration: 0.9,
                ease: "power2.out"
            }, arrival - 0.1)
            .fromTo(orbit + ".glow", { attr: { "fill-opacity": 0.5 } }, {
                attr: { "fill-opacity": 0 },
                duration: 0.9,
                ease: "power2.out"
            }, arrival - 0.1)
            .to(orbit + ".glow circle", { attr: { r: 5.22 }, duration: 0.6, ease: "power1.out" })
            .to(orbit + ".glow", { attr: { "fill-opacity": 0.18 }, duration: 0.6, ease: "power1.out" }, "<");

        return timeline;
    }

    function ripple(circle) {
        return gsap.fromTo(circle, { autoAlpha: 0.7, scale: 1, transformOrigin: "50% 50%" }, {
            immediateRender: false,
            autoAlpha: 0,
            scale: 3.2,
            duration: 0.8,
            ease: "power2.out"
        });
    }

    // What keeps moving once the journey is done: the arrow leans forward, the star twinkles,
    // the way back flows along the dashed ring, and now and then a light runs along the trail.
    // Returns the loops that start when the journey ends; the rest start now.
    function idle() {
        var orbit = ".orbit ";
        var loop = { ease: "sine.inOut", yoyo: true, repeat: -1, paused: true };
        var loops = [
            gsap.to(orbit + ".arrow", Object.assign({ x: 1.6, duration: 1.2 }, loop)),
            gsap.to(orbit + ".star", Object.assign({ scale: 1.12, rotation: 12, duration: 1.6 }, loop)),
            gsap.to(orbit + ".glow circle", Object.assign({ attr: { r: 7 }, duration: 1.6 }, loop)),
            gsap.to(orbit + ".glow", Object.assign({ attr: { "fill-opacity": 0.36 }, duration: 1.6 }, loop)),
            gsap.to(orbit + ".planet", Object.assign({ scale: 1.08, duration: 2.6 }, loop))
        ];

        gsap.to(orbit + ".ring", { strokeDashoffset: -96, duration: 30, ease: "none", repeat: -1 });

        gsap.timeline({ repeat: -1, repeatDelay: 5, delay: 5 })
            .set(orbit + ".pulse", { autoAlpha: 0 })
            .to(orbit + ".pulse", { autoAlpha: 0.9, duration: 0.25 })
            .to(orbit + ".pulse", {
                duration: 1.4,
                ease: "power1.inOut",
                motionPath: { path: "M16.44 47.56 A22 22 0 0 1 26.5 10.70" }
            }, 0)
            .to(orbit + ".pulse", { autoAlpha: 0, duration: 0.3 }, 1.15);

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
    function followPointer() {
        if (!window.matchMedia("(pointer: fine)").matches) {
            return;
        }

        var drift = [
            { target: ".orbit .orbit-drift", reach: 1.6 },
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

            drift.forEach(function (layer) {
                layer.x(dx * layer.reach * 2);
                layer.y(dy * layer.reach * 2);
            });
        });
    }

    // Scrolling down lifts the message away, tilts the mark back and lets the sky lag behind.
    // Coming back to the top replays the journey.
    function followScroll(replay) {
        var scrub = { trigger: hero, start: "top top", end: "bottom top", scrub: 0.6 };

        gsap.to(".hero-body", { y: -80, autoAlpha: 0.15, ease: "none", scrollTrigger: scrub });
        gsap.to(".scroll-cue", {
            autoAlpha: 0,
            ease: "none",
            scrollTrigger: { trigger: hero, start: "top top", end: "15% top", scrub: true }
        });
        gsap.to(".orbit .orbit-scroll", {
            y: 10,
            rotation: 14,
            scale: 0.86,
            svgOrigin: "32 32",
            ease: "none",
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
