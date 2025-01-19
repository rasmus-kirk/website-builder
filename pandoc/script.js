addEventListener('DOMContentLoaded', () => {
  const fullpath = location.origin + location.pathname.replace(/\/$/, "");

  document.querySelectorAll('nav a').forEach((el) => {
    const url = new URL(el.href);
    const fullurl = url.origin + url.pathname.replace(/\/$/, "");
    const onHome = fullpath === location.origin
    const urlIsHome = fullurl === location.origin

    if (onHome && fullurl === fullpath) {
      el.classList.add('active');
    }
    // The startsWith is for subpages
    else if (!urlIsHome && fullpath.startsWith(fullurl)) {
      el.classList.add('active');
    }
  });
});
