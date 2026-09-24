```
sbatch tests/test_basic.sh
```
if it errors about account, try:
```
sbatch -A <your_account> tests/test_basic.sh
```
- **Pass condition**: output file shows mem ≈100 and timelimit ≈1 minute. If those don't match what you requested, #SBATCH placement is broken.


```
sbatch tests/test_env.sh
```
- **Pass condition**: the "AFTER" python path points into your venv/conda env (not system python), and the import line prints OK with no traceback.

```
sbatch --export=CONFIG_FILE=config/conda_test.sh tests/test_export.sh
```
- **Pass condition**: output prints the real path, not "NOT SET".

```
sbatch --export=CONFIG_FILE=config/conda_test.sh tests/test_write.sh
cat <BASE_DIR_from_your_config>/logs/test_write_*.txt
```
- **Pass condition**: you can read the file from the login node after the compute job wrote it — confirms shared storage, which your whole pipeline depends on.

```
for i in {1..5}; do
    sbatch --export=CONFIG_FILE=config/conda_test.sh tests/test_concurrent.sh
done
ls <BASE_DIR>/logs/concurrent_test/
```
- **Pass condition**: exactly 5 distinct files, one per job ID, no missing/merged content.