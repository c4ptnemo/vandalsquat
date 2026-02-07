(() => {
  const nav = document.getElementById("site-navbar");
  const btn = document.getElementById("hamburger-btn");
  const menu = document.getElementById("mobile-menu");
  const overlay = document.getElementById("nav-overlay");

  if (!nav || !btn || !menu || !overlay) return;

  const isOpen = () => menu.classList.contains("active");

  const openMenu = () => {
    btn.classList.add("active");
    menu.classList.add("active");
    overlay.classList.add("active");
    btn.setAttribute("aria-expanded", "true");
    document.body.style.overflow = "hidden";
  };

  const closeMenu = () => {
    btn.classList.remove("active");
    menu.classList.remove("active");
    overlay.classList.remove("active");
    btn.setAttribute("aria-expanded", "false");
    document.body.style.overflow = "";
  };

  btn.addEventListener("click", () => {
    isOpen() ? closeMenu() : openMenu();
  });

  overlay.addEventListener("click", closeMenu);

  document.addEventListener("keydown", (e) => {
    if (e.key === "Escape" && isOpen()) closeMenu();
  });

  // Close when a link is tapped
  menu.querySelectorAll("a").forEach((a) => a.addEventListener("click", closeMenu));
})();
