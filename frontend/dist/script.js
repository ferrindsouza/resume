document.addEventListener('DOMContentLoaded', () => {
    // Smooth scrolling for navigation links
    document.querySelectorAll('nav a').forEach(anchor => {
        anchor.addEventListener('click', function (e) {
            // Check if the clicked anchor is for the download button (which has a 'download' attribute)
            if (this.hasAttribute('download')) {
                // Let the default behavior handle the download
                return true;
            }

            e.preventDefault();

            const targetId = this.getAttribute('href');
            // Check if targetId is an internal section link (starts with #)
            if (targetId && targetId.startsWith('#')) {
                document.querySelector(targetId).scrollIntoView({
                    behavior: 'smooth'
                });
            }
        });
    });
});
