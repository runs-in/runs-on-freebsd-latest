## Usage

```yml
on: push
jobs:
  build-napi-rs-freebsd:
    uses: runs-on/freebsd/.github/workflows/freebsd.yml@v1
    with:
      runs-on: freebsd-latest
      steps: |
        - uses: actions/checkout@v3
        - run: npm ci
        - run: npm run build
        - uses: actions/upload-artifact@v3
          with:
            name: build
            path: |
              index.js
              index.d.ts
              *.node
```

⚠️ `uses:` currently only works with **JavaScript-based** GitHub Actions. Some
JavaScript actions may require Linux-specific functionality and may not work on
FreeBSD. It's frankly a miracle that any work at all!
