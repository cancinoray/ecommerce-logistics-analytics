def test_dbt_imports_and_reports_version():
    import dbt.version

    assert dbt.version.installed.to_version_string()
