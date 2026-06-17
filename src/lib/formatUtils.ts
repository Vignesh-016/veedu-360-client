/**
 * Formats a number into Indian currency string, using Lakhs (L) and Crores (Cr)
 * for values >= 1 Lakh.
 * @param price - The numeric price value.
 * @returns Formatted price string (e.g., "₹ 1.50 L", "₹ 2.25 Cr", "₹ 50,000").
 */
export function formatPrice(price: number): string {
    if (typeof price !== 'number' || isNaN(price)) {
        return '₹ N/A';
    }

    const crore = 10000000;
    const lakh = 100000;

    if (price >= crore) {
        const value = (price / crore).toFixed(2);
        // Remove trailing .00 if present
        return `₹ ${value.endsWith('.00') ? value.slice(0, -3) : value} Cr`;
    } else if (price >= lakh) {
        const value = (price / lakh).toFixed(2);
        // Remove trailing .00 if present
        return `₹ ${value.endsWith('.00') ? value.slice(0, -3) : value} L`;
    } else {
        // Standard formatting for smaller amounts
        return `₹ ${price.toLocaleString('en-IN', { maximumFractionDigits: 0 })}`;
    }
}