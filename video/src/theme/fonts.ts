// Figtree (self-hosted, same file as the landing page) and JetBrains Mono for the tiny technical badges.
import { loadFont as loadMono } from '@remotion/google-fonts/JetBrainsMono';
import { continueRender, delayRender, staticFile } from 'remotion';

let started = false;

export const loadFonts = (): void => {
  if (started) {
    return;
  }
  started = true;
  loadMono('normal', { weights: ['700'], subsets: ['latin'] });
  const handle = delayRender('Loading Figtree');
  const face = new FontFace('Figtree', `url(${staticFile('figtree-var.woff2')}) format("woff2")`, {
    weight: '300 900',
  });
  face
    .load()
    .then((loaded) => {
      document.fonts.add(loaded);
      continueRender(handle);
    })
    .catch((err: unknown) => {
      console.error('Figtree failed to load', err);
      continueRender(handle);
    });
};
