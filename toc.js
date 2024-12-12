// Populate the sidebar
//
// This is a script, and not included directly in the page, to control the total size of the book.
// The TOC contains an entry for each page, so if each page includes a copy of the TOC,
// the total size of the page becomes O(n**2).
class MDBookSidebarScrollbox extends HTMLElement {
    constructor() {
        super();
    }
    connectedCallback() {
        this.innerHTML = '<ol class="chapter"><li class="chapter-item expanded "><a href="contracts/ronin_validator_set.html"><strong aria-hidden="true">1.</strong> Contracts</a></li><li><ol class="section"><li class="chapter-item expanded "><a href="contracts/profile.html"><strong aria-hidden="true">1.1.</strong> Profile</a></li><li class="chapter-item expanded "><a href="contracts/fast_finality_tracking.html"><strong aria-hidden="true">1.2.</strong> Fast Finality Tracking</a></li><li class="chapter-item expanded "><a href="contracts/ronin_trusted_organization.html"><strong aria-hidden="true">1.3.</strong> Ronin Trusted Organization</a></li><li class="chapter-item expanded "><a href="contracts/maintenance.html"><strong aria-hidden="true">1.4.</strong> Maintenance</a></li><li class="chapter-item expanded "><a href="contracts/ronin_random_beacon.html"><strong aria-hidden="true">1.5.</strong> Ronin Random Beacon</a></li><li class="chapter-item expanded "><a href="contracts/staking_vesting.html"><strong aria-hidden="true">1.6.</strong> Staking Vesting</a></li><li class="chapter-item expanded "><a href="contracts/ronin_basefee_treasury.html"><strong aria-hidden="true">1.7.</strong> Ronin Base Fee Treasury</a></li><li class="chapter-item expanded "><a href="contracts/slash_indicator.html"><strong aria-hidden="true">1.8.</strong> Slash Indicator</a></li></ol></li><li class="chapter-item expanded "><a href="core_concepts/epoch_vs_period.html"><strong aria-hidden="true">2.</strong> Core Concepts</a></li><li><ol class="section"><li class="chapter-item expanded "><a href="core_concepts/epoch_vs_period.html"><strong aria-hidden="true">2.1.</strong> Epoch vs Period</a></li><li class="chapter-item expanded "><a href="core_concepts/validator_roles.html"><strong aria-hidden="true">2.2.</strong> Validator Roles</a></li><li class="chapter-item expanded "><a href="core_concepts/renounce_vs_emergency_exit.html"><strong aria-hidden="true">2.3.</strong> Emergency Exit vs Renounce</a></li><li class="chapter-item expanded "><a href="core_concepts/staking_reward_calculation.html"><strong aria-hidden="true">2.4.</strong> Staking Reward Calculation</a></li></ol></li><li class="chapter-item expanded "><a href="technical_specifications/fast_finality_score_normalization.html"><strong aria-hidden="true">3.</strong> Technical Specifications</a></li><li><ol class="section"><li class="chapter-item expanded "><a href="technical_specifications/fast_finality_score_normalization.html"><strong aria-hidden="true">3.1.</strong> Fast Finality Score Normalization</a></li><li class="chapter-item expanded "><a href="technical_specifications/random_validator_selection.html"><strong aria-hidden="true">3.2.</strong> Random Validator Selection</a></li></ol></li><li class="chapter-item expanded "><a href="validator_lifecycle/block_based_op.html"><strong aria-hidden="true">4.</strong> Validator Lifecycle</a></li><li><ol class="section"><li class="chapter-item expanded "><a href="validator_lifecycle/emergency_exit.html"><strong aria-hidden="true">4.1.</strong> Emergency Exit</a></li><li class="chapter-item expanded "><a href="validator_lifecycle/renounce.html"><strong aria-hidden="true">4.2.</strong> Renounce</a></li><li class="chapter-item expanded "><a href="validator_lifecycle/block_based_op.html"><strong aria-hidden="true">4.3.</strong> Block-Based Operations</a></li><li class="chapter-item expanded "><a href="validator_lifecycle/epoch_based_op.html"><strong aria-hidden="true">4.4.</strong> Epoch-Based Operations</a></li></ol></li></ol>';
        // Set the current, active page, and reveal it if it's hidden
        let current_page = document.location.href.toString();
        if (current_page.endsWith("/")) {
            current_page += "index.html";
        }
        var links = Array.prototype.slice.call(this.querySelectorAll("a"));
        var l = links.length;
        for (var i = 0; i < l; ++i) {
            var link = links[i];
            var href = link.getAttribute("href");
            if (href && !href.startsWith("#") && !/^(?:[a-z+]+:)?\/\//.test(href)) {
                link.href = path_to_root + href;
            }
            // The "index" page is supposed to alias the first chapter in the book.
            if (link.href === current_page || (i === 0 && path_to_root === "" && current_page.endsWith("/index.html"))) {
                link.classList.add("active");
                var parent = link.parentElement;
                if (parent && parent.classList.contains("chapter-item")) {
                    parent.classList.add("expanded");
                }
                while (parent) {
                    if (parent.tagName === "LI" && parent.previousElementSibling) {
                        if (parent.previousElementSibling.classList.contains("chapter-item")) {
                            parent.previousElementSibling.classList.add("expanded");
                        }
                    }
                    parent = parent.parentElement;
                }
            }
        }
        // Track and set sidebar scroll position
        this.addEventListener('click', function(e) {
            if (e.target.tagName === 'A') {
                sessionStorage.setItem('sidebar-scroll', this.scrollTop);
            }
        }, { passive: true });
        var sidebarScrollTop = sessionStorage.getItem('sidebar-scroll');
        sessionStorage.removeItem('sidebar-scroll');
        if (sidebarScrollTop) {
            // preserve sidebar scroll position when navigating via links within sidebar
            this.scrollTop = sidebarScrollTop;
        } else {
            // scroll sidebar to current active section when navigating via "next/previous chapter" buttons
            var activeSection = document.querySelector('#sidebar .active');
            if (activeSection) {
                activeSection.scrollIntoView({ block: 'center' });
            }
        }
        // Toggle buttons
        var sidebarAnchorToggles = document.querySelectorAll('#sidebar a.toggle');
        function toggleSection(ev) {
            ev.currentTarget.parentElement.classList.toggle('expanded');
        }
        Array.from(sidebarAnchorToggles).forEach(function (el) {
            el.addEventListener('click', toggleSection);
        });
    }
}
window.customElements.define("mdbook-sidebar-scrollbox", MDBookSidebarScrollbox);
