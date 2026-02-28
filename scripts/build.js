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
      "src/init.lua",
    ];
    await createFxmanifest({
      client_scripts: [
        ...shared,
        "src/cfg/*.shared*.lua",
        "src/cfg/*.client*.lua",
        "src/client.lua",
      ],
      server_scripts: [
        ...shared,
        "src/cfg/*.shared*.lua",
        "src/cfg/*.server*.lua",
        "src/server.lua",
      ],
      files: [
        "lib/**/shared.lua",
        "lib/**/client.lua",
        "src/modules/**/shared.lua",
        "src/modules/**/client.lua",
        ...files
      ],
      dependencies: ['/server:13068', '/onesync'],
      metadata: {
        ui_page: 'dist/web/index.html',
      },
    });

    if (web && !watch) await exec("cd ./web && vite build");
  }
);

if (web && watch) await exec("cd ./web && vite build --watch");
