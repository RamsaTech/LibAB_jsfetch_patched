
import re
import sys

file_path = "/Users/techdna/Downloads/{b9db16a4-6edc-47ec-a1f4-b86292ed211d}/download_worker/libav-6.5.7.1-h264-aac-mp3.wasm.mjs"

try:
    with open(file_path, "r") as f:
        content = f.read()
except FileNotFoundError:
    print(f"File not found: {file_path}", file=sys.stderr)
    sys.exit(1)

def extract_func(name):
    # Try different patterns
    patterns = [f"function {name}", f"async function {name}"]
    start_idx = -1
    for p in patterns:
        start_idx = content.find(p)
        if start_idx != -1:
            break
    
    if start_idx == -1:
        # Try Module.name = ...
        p = f"Module.{name}="
        start_idx = content.find(p)
        if start_idx != -1:
             # This is a variable assignment, not a function declaration usually, 
             # but in the minified code it might be.
             # Actually, for Module.DoAbortableSleep = DoAbortableSleep; it's an assignment.
             # The definition is usually explicitly function name() earlier.
             pass
        return None

    # Find opening brace
    brace_idx = content.find("{", start_idx)
    if brace_idx == -1:
        return None
        
    count = 1
    idx = brace_idx + 1
    while count > 0 and idx < len(content):
        if content[idx] == '{':
            count += 1
        elif content[idx] == '}':
            count -= 1
        idx += 1
    
    return content[start_idx:idx]

functions_to_extract = [
    "jsfetch_init",
    "jsfetch_set_fetch_timeout_js",
    "jsfetch_set_read_timeout_js",
    "jsfetch_set_initial_retry_delay_js",
    "jsfetch_get_code",
    "jsfetch_abort",
    "jsfetch_set_bypass_cache_js",
    "jsfetch_abort_individual",
    "jsfetch_open_js",
    "jsfetch_support_range_js",
    "jsfetch_get_size_js",
    "jsfetch_get_pos_js",
    "jsfetch_read_js",
    "jsfetch_close_js",
    "DoAbortableSleep",
    "FetchWithRetry", 
    "FindPngSliceIndex"
]

print("mergeInto(LibraryManager.library, {")

for func in functions_to_extract:
    code = extract_func(func)
    if code:
        key = func
        # If it's a helper, we usually prefix with $. But here we might want to keep the name 
        # if the C code calls it (but C code calls via _jsfetch_... usually).
        # jsfetch_init etc are called by C?
        # In the patch, yes:
        # #define JS_FETCH_INIT "jsfetch_init()"
        # So they must be available in the global scope / library scope.
        
        # However, `DoAbortableSleep` etc are helper JS functions called by OTHER JS functions.
        # If we put them in the library object, `jsfetch_init` can call them via `_DoAbortableSleep`?
        # No, in Emscripten library, if you use `name: function...`, it becomes `_name` in C 
        # but inside JS library functions you can call other library functions?
        # Usually dependencies are needed.
        
        # Since the original code had them as top-level functions in the module scope, 
        # enabling them in the library might require `__deps`.
        
        # For now, let's just dump them. I'll manually clean up if needed.
        # I will change `async function {name}` to `name: async function`
        # and `function {name}` to `name: function`
        
        cleaned_code = code
        if "async function" in code:
            cleaned_code = code.replace(f"async function {func}", "async function")
        else:
            cleaned_code = code.replace(f"function {func}", "function")
            
        print(f"  {key}: {cleaned_code},")
    else:
        print(f"// Failed to extract {func}")

print("});")
