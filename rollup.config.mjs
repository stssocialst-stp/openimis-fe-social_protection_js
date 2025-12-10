import json from '@rollup/plugin-json';
import { readFileSync } from 'fs';
import { createRequire } from 'module';

// Alguns plugins exportam CommonJS; usar createRequire para compatibilidade
const require = createRequire(import.meta.url);
const babelPkg = require('@rollup/plugin-babel');
const babel = babelPkg && (babelPkg.default || babelPkg);

// Em ESM no Node 16 a importação direta de JSON exige 'assert'.
// Ler manualmente evita a necessidade de atualizar o Node/npm no CI.
const pkg = JSON.parse(readFileSync(new URL('./package.json', import.meta.url)));

export default {
	input: 'src/index.js',
	output: [
		{
			file: pkg.module,
			format: 'es',
			sourcemap: true,
		},
		{
			file: 'dist/index.js',
			format: 'cjs',
			sourcemap: true,
		},
	],
	external: [
		/^@babel.*/,
		/^@date-io\/.*/,
		/^@material-ui\/.*/,
		/^@openimis.*/,
		'classnames',
		'clsx',
		'history',
		/^lodash.*/,
		'moment',
		'prop-types',
		/^react.*/,
		/^redux.*/,
	],
	plugins: [
		json(),
		babel({
			exclude: 'node_modules/**',
			babelHelpers: 'runtime',
		}),
	],
};