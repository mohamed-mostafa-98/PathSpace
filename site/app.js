document.getElementById('year').textContent = new Date().getFullYear();
if (location.hash) setTimeout(() => document.querySelector(location.hash)?.scrollIntoView(), 150);
