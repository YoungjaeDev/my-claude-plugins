// Generic motions shipped with the deck template. Only from/fromTo on [data-anim], so the authored DOM is the end state.
//
// loop: svg.loop with [data-anim] center, ring (a path), arrows, dot (orbits the ring), node and step.
// convert: .convert rows, each [data-anim="row"] holding [data-anim] from, arrow and to.
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
});
