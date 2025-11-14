/* ===== HERO CAROUSEL - IMAGE CONFIGURATION ===== */
const heroImages = [
    '/images/posts/pexels-pixabay-159304.jpg',
    '/images/posts/pexels-luis-gomes-166706-546819.jpg',
    '/images/posts/pexels-kevin-ku-92347-577585.jpg',
    '/images/posts/pexels-johnpet-2115257.jpg'
];

/* ===== INITIALIZE VARIABLES ===== */
let currentIndex = 0;
const hero = document.querySelector('.hero');

/* ===== HERO CAROUSEL INITIALIZATION ===== */
if (hero) {
    console.log('Hero element found, initializing carousel...');
    
    // Set initial image
    updateHeroImage();
    
    // Detect if mobile device
    const isMobile = window.innerWidth <= 768;
    
    // Set interval based on device type
    // Mobile: 10 seconds, Desktop: 6 seconds
    const interval = isMobile ? 10000 : 6000;
    
    console.log('Device type:', isMobile ? 'Mobile/Tablet' : 'Desktop');
    console.log('Image change interval:', interval + 'ms');
    
    // Change image at set interval
    setInterval(() => {
        currentIndex = (currentIndex + 1) % heroImages.length;
        console.log('Switching to image:', heroImages[currentIndex]);
        updateHeroImage();
    }, interval);
}

/* ===== UPDATE HERO BACKGROUND IMAGE WITH FADE ===== */
function updateHeroImage() {
    const img = heroImages[currentIndex];
    console.log('Setting background image:', img);
    
    // Add fade out effect
    hero.style.opacity = '0.8';
    
    // Change image after fade starts
    setTimeout(() => {
        hero.style.backgroundImage = `url('${img}')`;
        // Fade back in
        hero.style.opacity = '1';
    }, 200);
}

/* ===== PRELOAD IMAGES FOR SMOOTH TRANSITIONS ===== */
function preloadImages() {
    heroImages.forEach(src => {
        const img = new Image();
        img.src = src;
        img.onerror = () => console.warn('Failed to load image:', src);
    });
}

/* ===== PRELOAD IMAGES WHEN PAGE LOADS ===== */
window.addEventListener('load', preloadImages);