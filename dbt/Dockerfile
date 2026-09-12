FROM ghcr.io/astral-sh/uv:python3.12-bookworm-slim

# git is required by `dbt debug`'s dependency check and by dbt's package
# manager (git-hosted packages), but isn't in the slim base image.
RUN apt-get update && apt-get install -y --no-install-recommends git \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /dbt

COPY pyproject.toml uv.lock ./
RUN uv sync --locked --no-install-project

COPY . .

ENV PATH="/dbt/.venv/bin:$PATH"

CMD ["dbt", "--help"]
