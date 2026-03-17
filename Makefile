AWS_PROFILE ?= terraform-dev

.PHONY: fuse

fuse:
	# Disable wasm-opt: crashes with SIGBUS on some Apple Silicon Macs (and binaryen is not installed in CI)
	sed -i.bak 's/^wasm-opt = \["-Os", "-g"\]$$/wasm-opt = false/' frontend/wasm/Cargo.toml
	rm -f frontend/wasm/Cargo.toml.bak
	# Graphite requires Node ^20.19.0 or >=22.12.0 (Vite 7 constraint)
	@node -e "const v=process.versions.node.split('.').map(Number); \
	  const ok=(v[0]===20&&v[1]>=19)||(v[0]>=22); \
	  if(!ok){console.error('fuse requires Node ^20.19.0 or >=22.12.0 (current: '+process.version+')');process.exit(1)}"
	# Build with /draw/ as the base path
	# System requirements: Rust, wasm-pack, cargo-about
	cd frontend && npm install && npm run setup && npm run wasm:build-production && npx vite build --base=/draw/
	# Resolve S3 bucket from SSM and sync
	@BUCKET=$$(aws ssm get-parameter \
		--name /laravel/satellite-apps-bucket \
		--query Parameter.Value \
		--output text \
		--profile $(AWS_PROFILE)); \
	echo "Syncing to s3://$$BUCKET/graphite/ (profile: $(AWS_PROFILE))..."; \
	aws s3 sync frontend/dist/ s3://$$BUCKET/graphite/ --delete --profile $(AWS_PROFILE)
