FROM ghcr.io/astral-sh/uv:python3.12-bookworm-slim

WORKDIR /dbt

COPY pyproject.toml uv.lock ./
RUN uv sync --locked --no-install-project

COPY . .

ENV PATH="/dbt/.venv/bin:$PATH"

CMD ["dbt", "--help"]
