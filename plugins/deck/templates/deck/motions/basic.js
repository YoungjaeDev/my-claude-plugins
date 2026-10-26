// Generic motions shipped with the deck template. Only from/fromTo on [data-anim], so the authored DOM is the end state.
//
// loop: svg.loop with [data-anim] center, ring (a path), arrows, dot (orbits the ring), node and step.
// convert: .convert rows, each [data-anim="row"] holding [data-anim] from, arrow and to.
// hops: [data-anim] node boxes and link lines appear, then each [data-anim="hop"] plays in data-order
//   (DOM order when equal; hops without one play last), then [data-anim="case"].
//   data-from="x,y x,y ..." travels from those offsets (start, then each corner) to the authored spot; a travelling
//   svg circle (packet dot, authored opacity="0") fades out at the end. A .swap hop hides its first child and shows
//   its last. A .page.before hop (an earlier page over a .browser-win) fades out. An svg rect hop with data-width
//   grows or shrinks from that width to its authored width. Any other hop fades in.
window.DECK_MOTIONS = Object.assign(window.DECK_MOTIONS || {}, {
  loop(slide) {
    const q = name => slide.querySelectorAll(`[data-anim="${name}"]`);
    const ring = slide.querySelector('[data-anim="ring"]');
    const length = ring.getTotalLength();
    const box = ring.getBBox();
    return gsap.timeline({ defaults: { ease: "power2.out" } })
      .from(q("center"), { opacity: 0, duration: 0.4 })
      .fromTo(ring, { strokeDasharray: length, strokeDashoffset: length }, { strokeDashoffset: 0, duration: 0.8 })
      .from(q("arrows"), { opacity: 0, duration: 0.3 })
      .addLabel("orbit")
      .from(q("dot"), { rotation: -360, svgOrigin: `${box.x + box.width / 2} ${box.y + box.height / 2}`, duration: 3, ease: "none" }, "orbit")
      .from(q("node"), { opacity: 0, scale: 0.85, transformOrigin: "50% 50%", duration: 0.35, stagger: 0.6 }, "orbit")
      .from(q("step"), { opacity: 0, x: -16, duration: 0.35, stagger: 0.6 }, "orbit");
  },
  convert(slide) {
    const tl = gsap.timeline({ defaults: { ease: "power2.out", duration: 0.35 } });
    slide.querySelectorAll('[data-anim="row"]').forEach((row, i) => {
      const [from, arrow, to] = ["from", "arrow", "to"].map(name => row.querySelector(`[data-anim="${name}"]`));
      const at = i * 0.8;
      tl.from(from, { opacity: 0, x: -24 }, at)
        .from(arrow, { scaleX: 0, transformOrigin: "0 50%" }, at + 0.25)
        .from(to, { opacity: 0, x: -24 }, at + 0.5);
    });
    return tl;
  },
  hops(slide) {
    const q = name => slide.querySelectorAll(`[data-anim="${name}"]`);
    const tl = gsap.timeline({ defaults: { ease: "power2.out", duration: 0.4 } })
      .from(q("node"), { opacity: 0, y: 16, stagger: 0.3 })
      .from(q("link"), { opacity: 0 });
    const hops = [...q("hop")].map((el, i) => [el.dataset.order ? +el.dataset.order : Infinity, i, el]).sort((a, b) => a[0] - b[0] || a[1] - b[1]);
    for (const [, , el] of hops) {
      if (el.dataset.from) {
        const pts = el.dataset.from.split(" ").map(p => p.split(",").map(Number)).concat([[0, 0]]);
        // immediateRender off: an end-state element revealed on its turn stays as authored (a packet hidden) until then
        pts.slice(1).forEach(([x, y], k) => {
          const [fx, fy] = pts[k];
          tl.fromTo(el, { x: fx, y: fy, opacity: 1 }, { x, y, opacity: 1, duration: 0.5, ease: "none", immediateRender: false }, k ? ">" : "+=0.15");
        });
        if (el.tagName === "circle") tl.fromTo(el, { opacity: 1 }, { opacity: 0, duration: 0.2, immediateRender: false });
      } else if (el.classList.contains("swap")) {
        // immediateRender on (default): the old value shows and the new one hides from the first frame
        tl.fromTo(el.firstElementChild, { opacity: 1 }, { opacity: 0, duration: 0.6 }, "+=0.3")
          .fromTo(el.lastElementChild, { opacity: 0 }, { opacity: 1, duration: 0.6 }, "<");
      } else if (el.matches(".page.before")) {
        tl.fromTo(el, { opacity: 1 }, { opacity: 0, duration: 0.6 }, "+=0.2");
      } else if (el.dataset.width) {
        tl.fromTo(el, { attr: { width: +el.dataset.width } }, { attr: { width: +el.getAttribute("width") }, duration: 2.5, ease: "none" });
      } else {
        tl.from(el, { opacity: 0, y: 12 });
      }
    }
    return tl.from(q("case"), { opacity: 0, y: 12 }, "+=0.3");
  },
});
