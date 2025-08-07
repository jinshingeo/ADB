#!/bin/tcsh

# =================================================================
#                 SLURM 작업 스크립트 설정
# =================================================================

# --- 작업 기본 정보 ---

#SBATCH --job-name=tif_to_csv
#SBATCH --output=R-%x.%j.out
#SBATCH --error=R-%x.%j.err

# --- 리소스 할당 ---
#SBATCH --nodes=1

#SBATCH --time=11:59:00

# --- 이메일 알림 (선택 사항) ---
#SBATCH --mail-type=all
#SBATCH --mail-user=2019103677@khu.ac.kr

# =================================================================
#                      작업 실행 명령어
# =================================================================

# 실제 작업을 실행합니다.
# conda run -n ox_jp python calculate_od_matrix_emd_parallel.py 
python CCI_LC_tif_to_CSV.py