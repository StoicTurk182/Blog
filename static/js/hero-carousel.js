// Hero Carousel Script
// Manages cycling background images on hero sections

const heroImages = [
    '/images/posts/pexels-pixabay-159304.jpg',
    '/images/posts/pexels-luis-gomes-166706-546819.jpg',
    '/images/posts/pexels-kevin-ku-92347-577585.jpg',
    '/images/posts/pexels-johnpet-2115257.jpg'
];

let currentIndex = 0;
const hero = document.querySelector('.hero');

if (hero) {
    console.log('Hero element found, initializing carousel...');
    
    updateHeroImage();
    
    setInterval(() => {
        currentIndex = (currentIndex + 1) % heroImages.length;
        console.log('Switching to image:', heroImages[currentIndex]);
        updateHeroImage();
    }, 6000);
}

function updateHeroImage() {
    const img = heroImages[currentIndex];
    console.log('Setting background image:', img);
    hero.style.backgroundImage = `url('${img}')`;
}

// Preload images
function preloadImages() {
    heroImages.forEach(src => {
        const img = new Image();
        img.src = src;
        img.onerror = () => console.warn('Failed to load image:', src);
    });
}

window.addEventListener('load', preloadImages);