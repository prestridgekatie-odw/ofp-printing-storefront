document.addEventListener('DOMContentLoaded', () => {
  const toggle = document.querySelector('[data-menu-toggle]');
  const navigation = document.querySelector('[data-site-navigation]');

  if (toggle && navigation) {
    toggle.addEventListener('click', () => {
      const expanded = toggle.getAttribute('aria-expanded') === 'true';
      toggle.setAttribute('aria-expanded', String(!expanded));
      navigation.classList.toggle('is-open', !expanded);
    });

    navigation.addEventListener('click', (event) => {
      if (event.target.closest('a')) {
        toggle.setAttribute('aria-expanded', 'false');
        navigation.classList.remove('is-open');
      }
    });
  }

  const sortSelect = document.querySelector('[data-sort-select]');
  if (sortSelect) {
    sortSelect.addEventListener('change', () => {
      const url = new URL(window.location.href);
      url.searchParams.set('sort_by', sortSelect.value);
      window.location.assign(url.toString());
    });
  }

  const variantSelect = document.querySelector('[data-variant-select]');
  if (variantSelect) {
    variantSelect.addEventListener('change', () => {
      const option = variantSelect.selectedOptions[0];
      const price = document.querySelector('[data-current-price]');
      const comparePrice = document.querySelector('[data-compare-price]');
      const addToCart = document.querySelector('[data-add-to-cart]');

      if (price) price.textContent = option.dataset.price;
      if (comparePrice) {
        comparePrice.textContent = option.dataset.comparePrice;
        comparePrice.hidden = !option.dataset.comparePrice;
      }
      if (addToCart) {
        addToCart.disabled = option.disabled;
        addToCart.textContent = option.disabled ? 'Sold out' : 'Add to cart';
      }
    });
  }
});