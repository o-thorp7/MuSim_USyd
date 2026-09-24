for i in {1..5}; do
    sbatch --export=CONFIG_FILE=config/venv_test.sh tests/test_concurrent.sh
done