/* ===== HERO CAROUSEL CONFIGURATION ===== */
const heroImages = [
    '/images/posts/pexels-pixabay-159304.jpg',
    '/images/posts/pexels-luis-gomes-166706-546819.jpg',
    '/images/posts/pexels-kevin-ku-92347-577585.jpg',
    '/images/posts/pexels-johnpet-2115257.jpg'
];

let currentIndex = 0;
const hero = document.querySelector('.hero');

if (hero) {
    // 1. Set the initial image via the CSS variable
    hero.style.setProperty('--hero-bg', `url('${heroImages[currentIndex]}')`);

    const isMobile = window.innerWidth <= 768;
    const interval = isMobile ? 10000 : 6000;

    setInterval(() => {
        // 2. Trigger the CSS fade-out (opacity: 0 on ::before)
        hero.classList.add('fade-out');

        // 3. Wait for the fade-out to finish (matching your 1.5s CSS transition)
        setTimeout(() => {
            currentIndex = (currentIndex + 1) % heroImages.length;
            const nextImgPath = heroImages[currentIndex];
            
            // 4. Swap the image path in the CSS variable
            hero.style.setProperty('--hero-bg', `url('${nextImgPath}')`);

            // 5. Trigger the CSS fade-in
            hero.classList.remove('fade-out');
        }, 1500); 
    }, interval);
}

/* ===== PRELOAD IMAGES ===== */
function preloadImages() {
    heroImages.forEach(src => {
        const img = new Image();
        img.src = src;
    });
}
window.addEventListener('load', preloadImages);