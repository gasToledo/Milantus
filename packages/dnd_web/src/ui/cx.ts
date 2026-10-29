/** Junta clases y descarta las vacías: `cx('card', open && 'is-open')`. */
export const cx = (...parts: (string | false | null | undefined)[]): string =>
  parts.filter(Boolean).join(' ');
