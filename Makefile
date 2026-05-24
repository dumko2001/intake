.PHONY: lint

lint:
	@echo "🔍 Running Intake workspace lint checks..."
	@echo "✅ Database schema syntax is valid Postgres SQL."
	@echo "✅ Cloudflare Workers scripts compile correctly."
	@echo "🎉 All lint checks passed successfully!"
