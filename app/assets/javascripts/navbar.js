<script>
  (function () {
    const nav = document.getElementById("site-navbar");
    const btn = document.getElementById("hamburger-btn");
    const overlay = document.getElementById("nav-overlay");
    if (!nav || !btn || !overlay) return;

    function openMenu() {
      nav.classList.add("is-open");
      btn.classList.add("active");
      btn.setAttribute("aria-expanded", "true");
      document.body.style.overflow = "hidden";
    }

    function closeMenu() {
      nav.classList.remove("is-open");
      btn.classList.remove("active");
      btn.setAttribute("aria-expanded", "false");
      document.body.style.overflow = "";
    }

    btn.addEventListener("click", () => {
      nav.classList.contains("is-open") ? closeMenu() : openMenu();
    });

    overlay.addEventListener("click", closeMenu);

    document.addEventListener("keydown", (e) => {
      if (e.key === "Escape") closeMenu();
    });
  })();
</script>
