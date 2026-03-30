{
  "targets": [
    {
      "target_name": "verity_napi",
      "sources": ["verity_napi.c"],
      "include_dirs": ["../../../core/include"],
      "conditions": [
        ["OS=='mac'", {
          "libraries": [
            "-L../../../core/target/release",
            "-lbarretenberg_ffi"
          ]
        }],
        ["OS=='linux'", {
          "libraries": [
            "-L../../../core/target/release",
            "-lbarretenberg_ffi"
          ]
        }]
      ]
    }
  ]
}
