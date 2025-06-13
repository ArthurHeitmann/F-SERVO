/* tslint:disable */
/* eslint-disable */
export function rpu_load_wmb_from_path(wmb_path: number): number;
export function rpu_load_wmb_from_bytes(name: number, wmb: number, wmb_size: number, wta_wtb: number, wta_wtb_size: number, wtp: number, wtp_size: number): number;
export function rpu_new_context(): number;
export function rpu_new_renderer(context: number, width: number, height: number, scene_data: number): number;
export function rpu_drop_renderer(state: number): void;
export function rpu_render(state: number, buffer: number, buffer_size: number, width: number, height: number, bg_r: number, bg_g: number, bg_b: number, bg_a: number): number;
export function rpu_add_camera_rotation(state: number, x: number, y: number): void;
export function rpu_add_camera_offset(state: number, x: number, y: number): void;
export function rpu_zoom_camera_by(state: number, distance: number): void;
export function rpu_auto_set_target(state: number): void;
export function rpu_set_model_visibility(state: number, model_id: number, visibility: boolean): void;
export function rpu_get_model_states(state: number): number;
export function malloc(size: number): number;
export function free(ptr: number): void;

export type InitInput = RequestInfo | URL | Response | BufferSource | WebAssembly.Module;

export interface InitOutput {
  readonly memory: WebAssembly.Memory;
  readonly rpu_load_wmb_from_path: (a: number) => number;
  readonly rpu_load_wmb_from_bytes: (a: number, b: number, c: number, d: number, e: number, f: number, g: number) => number;
  readonly rpu_new_context: () => number;
  readonly rpu_new_renderer: (a: number, b: number, c: number, d: number) => number;
  readonly rpu_drop_renderer: (a: number) => void;
  readonly rpu_render: (a: number, b: number, c: number, d: number, e: number, f: number, g: number, h: number, i: number) => number;
  readonly rpu_add_camera_rotation: (a: number, b: number, c: number) => void;
  readonly rpu_add_camera_offset: (a: number, b: number, c: number) => void;
  readonly rpu_zoom_camera_by: (a: number, b: number) => void;
  readonly rpu_auto_set_target: (a: number) => void;
  readonly rpu_set_model_visibility: (a: number, b: number, c: number) => void;
  readonly rpu_get_model_states: (a: number) => number;
  readonly malloc: (a: number) => number;
  readonly free: (a: number) => void;
  readonly __wbindgen_exn_store: (a: number) => void;
  readonly __externref_table_alloc: () => number;
  readonly __wbindgen_export_2: WebAssembly.Table;
  readonly __wbindgen_malloc: (a: number, b: number) => number;
  readonly __wbindgen_realloc: (a: number, b: number, c: number, d: number) => number;
  readonly __wbindgen_free: (a: number, b: number, c: number) => void;
  readonly __wbindgen_export_6: WebAssembly.Table;
  readonly closure458_externref_shim: (a: number, b: number, c: any) => void;
  readonly _dyn_core__ops__function__FnMut_____Output___R_as_wasm_bindgen__closure__WasmClosure___describe__invoke__h34531c103fe6ffcb: (a: number, b: number) => void;
  readonly closure904_externref_shim: (a: number, b: number, c: any) => void;
  readonly __wbindgen_start: () => void;
}

export type SyncInitInput = BufferSource | WebAssembly.Module;
/**
* Instantiates the given `module`, which can either be bytes or
* a precompiled `WebAssembly.Module`.
*
* @param {{ module: SyncInitInput }} module - Passing `SyncInitInput` directly is deprecated.
*
* @returns {InitOutput}
*/
export function initSync(module: { module: SyncInitInput } | SyncInitInput): InitOutput;

/**
* If `module_or_path` is {RequestInfo} or {URL}, makes a request and
* for everything else, calls `WebAssembly.instantiate` directly.
*
* @param {{ module_or_path: InitInput | Promise<InitInput> }} module_or_path - Passing `InitInput` directly is deprecated.
*
* @returns {Promise<InitOutput>}
*/
export default function __wbg_init (module_or_path?: { module_or_path: InitInput | Promise<InitInput> } | InitInput | Promise<InitInput>): Promise<InitOutput>;
