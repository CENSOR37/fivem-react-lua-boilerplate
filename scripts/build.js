//@ts-check

import { exists, exec, getFiles } from './utils.js';
import { createBuilder, createFxmanifest } from '@overextended/fx-utils';

const watch = process.argv.includes('--watch');
const web = await exists('./web');
const dropLabels = ['$BROWSER'];

if (!watch) dropLabels.push('$DEV');

createBuilder(
  watch,
  {
    keepNames: true,
    legalComments: 'inline',
    bundle: true,
    treeShaking: true,
  },
  [],
  async (outfiles) => {
    const files = await getFiles('dist/web', 'static', 'locales');
    const shared = [
      "@censorlib/imports.lua",
      "@es_extended/imports.lua",
      "init.lua",
      "vendors/*.shared*.lua",
      "vendors/**/shared.lua",
      "cfg/*.shared*.lua",
    ];
    await createFxmanifest({
      client_scripts: [
        ...shared,
        "vendors/*.client*.lua",
        "vendors/**/client.lua",
        "lib/*.shared*.lua",
        "lib/**/shared.lua",
        "lib/*.client*.lua",
        "lib/**/client.lua",
        "cfg/*.server*.lua",
        "src/*.shared*.lua",
        "src/*.client*.lua",
        "src/**/shared.lua",
        "src/**/client.lua",
      ],
      server_scripts: [
        ...shared,
        "vendors/*.server*.lua",
        "vendors/**/server.lua",
        "lib/*.shared*.lua",
        "lib/**/shared.lua",
        "lib/*.server*.lua",
        "lib/**/server.lua",
        "cfg/*.server*.lua",
        "src/*.shared*.lua",
        "src/*.server*.lua",
        "src/**/shared.lua",
        "src/**/server.lua",
      ],
      files: ['lib/init.lua', 'lib/client/**.lua', 'locales/*.json', ...files],
      dependencies: ['/server:13068', '/onesync'],
      metadata: {
        ui_page: 'dist/web/index.html',
      },
    });

    if (web && !watch) await exec("cd ./web && vite build");
  }
);

if (web && watch) await exec("cd ./web && vite build --watch");
