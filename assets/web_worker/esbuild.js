import esbuild from "esbuild"
import { typecheckPlugin } from "@jgoz/esbuild-plugin-typecheck";

const watch = process.argv.includes("--watch") || process.argv.includes("-w");

const context = await esbuild.context({
	entryPoints: [
		"src/worker.ts",
		"src/worker_base.ts",
	],
	outdir: "./dist",
	bundle: true,
	sourcemap: true,
	platform: "neutral",
	loader: {
		".wasm": "binary",
	},
	define: {
		"import.meta.url": "null",
	},
	plugins: [
		typecheckPlugin({
			watch: watch,
			omitStartLog: true,
		})
	],
});

if (watch) {
	await context.watch();
}
else {
	await context.rebuild();
	await context.dispose();
}
