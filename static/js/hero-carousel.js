// Hero Carousel Script - Performance Optimizations Only
// DOES NOT change visual effect - only adds scroll pause and tab pause

const heroImages = [
    '/images/posts/pexels-pixabay-159304.jpg',
    '/images/posts/pexels-luis-gomes-166706-546819.jpg',
    '/images/posts/pexels-kevin-ku-92347-577585.jpg',
    '/images/posts/pexels-johnpet-2115257.jpg'
];

let currentIndex = 0;
let imagesPreloaded = false;
let carouselInterval = null;
let isScrolling = false;
let scrollTimeout = null;

// Preload all images first
function preloadImages() {
    let loadedCount = 0;
    const totalImages = heroImages.length;
    
    heroImages.forEach(src => {
        const img = new Image();
        img.onload = () => {
            loadedCount++;
            if (loadedCount === totalImages) {
                imagesPreloaded = true;
                initCarousel();
            }
        };
        img.onerror = () => {
            console.warn('Failed to load image:', src);
            loadedCount++;
            if (loadedCount === totalImages) {
                imagesPreloaded = true;
                initCarousel();
            }
        };
        img.src = src;
    });
}

function initCarousel() {
    const hero = document.querySelector('.hero');
    
    if (!hero) {
        console.log('No hero element found');
        return;
    }
    
    console.log('Hero carousel initialized');
    
    // Set initial image
    updateHeroImage(hero);
    
    // Start rotation
    startCarousel(hero);
    
    // PERFORMANCE: Pause during scrolling
    window.addEventListener('scroll', () => {
        handleScroll(hero);
    }, { passive: true });
    
    // PERFORMANCE: Pause when tab is hidden
    document.addEventListener('visibilitychange', () => {
        if (document.hidden) {
            pauseCarousel();
        } else {
            resumeCarousel(hero);
        }
    });
}

function startCarousel(hero) {
    if (carouselInterval) {
        clearInterval(carouselInterval);
    }
    
    carouselInterval = setInterval(() => {
        // Only run if not scrolling and tab is visible
        if (!isScrolling && !document.hidden) {
            currentIndex = (currentIndex + 1) % heroImages.length;
            updateHeroImage(hero);
        }
    }, 6000);
}

function pauseCarousel() {
    if (carouselInterval) {
        clearInterval(carouselInterval);
        carouselInterval = null;
    }
}

function resumeCarousel(hero) {
    if (!carouselInterval) {
        startCarousel(hero);
    }
}

function handleScroll(hero) {
    isScrolling = true;
    
    if (scrollTimeout) {
        clearTimeout(scrollTimeout);
    }
    
    // Resume 300ms after scrolling stops
    scrollTimeout = setTimeout(() => {
        isScrolling = false;
    }, 300);
}

function updateHeroImage(hero) {
    const img = heroImages[currentIndex];
    
    // EXACT SAME TRANSITION AS YOUR CURRENT VERSION
    // Just direct background image swap - CSS handles the transition
    hero.style.backgroundImage = `url('${img}')`;
}

// Start preloading when page loads
window.addEventListener('load', preloadImages);