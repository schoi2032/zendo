// Static hosting can mount the app beneath a repository path, e.g. /zendo.
export const basePath = process.env.NEXT_PUBLIC_BASE_PATH ?? '';
export const appHome = `${basePath}/`;
export const authCallback = `${basePath}/auth/callback/`;
