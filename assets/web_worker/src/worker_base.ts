import init, { callMain, FS } from "./vgmstream-cli.js";
import {
	initializeImageMagick,
	ImageMagick,
	MagickFormat,
} from '@imagemagick/magick-wasm';

type WorkerMessageType = "echo" | "wem_to_wav" | "img_to_png" | "img_to_dds" | "error";
interface WorkerMessage {
	id: number;
	type: WorkerMessageType;
	args: {[name: string]: any};
}

export async function onMessage(eventData: any, postMessage: (message: WorkerMessage) => void) {

	const { id, type, args } = eventData as WorkerMessage;
	console.log("Worker message", type);
	if (type === "echo") {
		postMessage({
			id,
			type: "echo",
			args,
		});
	}
	else if (type === "wem_to_wav") {
		await initPromise;
		const t1 = performance.now();
		FS.writeFile("/tmp.wem", args["bytes"]);
		const vgmStreamArgs = ["-o", "/tmp.wav", "/tmp.wem"];
		const result = callMain(vgmStreamArgs);
		let wav: Uint8Array | null = null;
		if (result === 0) {
			wav = FS.readFile("/tmp.wav", { encoding: "binary" });
		}
		const t2 = performance.now();
		console.log(`wem_to_wav took ${t2 - t1}ms`);
		
		postMessage({
			id,
			type,
			args: {bytes: wav},
		});
	}
	else if (type === "img_to_png") {
		await initPromise;
		const t1 = performance.now();
		const img = args["bytes"] as Uint8Array;
		const maxHeight = args["maxHeight"];
		const png = await new Promise(res => ImageMagick.read(img, (image) => {
			if (maxHeight) {
				const scale = maxHeight / image.height;
				const width = Math.round(image.width * scale);
				image.resize(width, maxHeight);
			}
			image.write(MagickFormat.Png, (png) => res(cloneUint8Array(png)));
		}));
		const t2 = performance.now();
		console.log(`img_to_png took ${t2 - t1}ms`);
		
		postMessage({
			id,
			type,
			args: {bytes: png},
		});
	}
	else if (type === "img_to_dds") {
		await initPromise;
		const t1 = performance.now();
		const img = args["bytes"] as Uint8Array;
		const ddsFormat = args["format"] === "dxt1" ? MagickFormat.Dxt1 : MagickFormat.Dxt5;
		const mipmaps = args["mipmaps"] ? 10 : 0;
		const dds = await new Promise(res => ImageMagick.read(img, (image) => {
			image.settings.setDefine("dds:compression", ddsFormat);
			image.settings.setDefine("dds:mipmaps", mipmaps.toString());
			image.write(ddsFormat, (dds) => res(cloneUint8Array(dds)));
		}));
		const t2 = performance.now();
		console.log(`img_to_dds took ${t2 - t1}ms`);
		
		postMessage({
			id,
			type,
			args: {bytes: dds},
		});
	}
	else {
		postMessage({
			id,
			type: "error",
			args: {},
		});
	}
};

function consoleBuffer(log: (str: string) => void) {
	const buffer = [];
	const newLineCode = "\n".charCodeAt(0);
	return (code) => {
		if (code === newLineCode) {
			const str = String.fromCharCode(...buffer);
			log(str);
			buffer.length = 0;
		} else {
			buffer.push(code);
		}
	};

}

const isWorker = typeof WorkerGlobalScope != "undefined";
function getPathToFile(file: string) {
	if (isWorker) {
		return `./${file}`;
	} else {
		return `./assets/assets/web_worker/dist/${file}`;
	}
}

const initPromise = new Promise(async (resolve, reject) => {
	init({
		preRun: () => {
			FS.init(undefined, consoleBuffer(console.log), consoleBuffer(console.error));
		},
		locateFile: (path: string) => {
			if (path === "vgmstream-cli.wasm") {
				return getPathToFile("vgmstream-cli.wasm");
			}
			throw new Error(`File not found: ${path}`);
		},
	});

	var magickWasmUrl = new URL(getPathToFile("magick.wasm"), location.href);
	await initializeImageMagick(magickWasmUrl);

	resolve(0);
});

function cloneUint8Array(arr: Uint8Array) {
	const newArr = new Uint8Array(arr.length);
	newArr.set(arr);
	return newArr;
}
