#!/usr/bin/env bash
# =====================================================================
# Runner stress test: menjalankan pgbench di container PostgreSQL, menyimpan log,
# mengirim TPS/latensi ke node_exporter (textfile collector), dan membuat annotation Grafana.
#
# Pemakaian:
#   ./jalankan_uji.sh step    <label>   # matriks: 1, 5, 10, 20, 40, 80 klien, campuran T1-T6
#   ./jalankan_uji.sh spike   <label>   # fase 4: lonjakan pagi
#   ./jalankan_uji.sh laporan <label>   # fase 5: laporan berat di jam sibuk
#   ./jalankan_uji.sh soak    <label>   # fase 8: beban konstan lama
#
# Contoh label: V1_tanpa_index, V2_tanpa_index, V2_dengan_index
#
# Pengaturan lewat environment variable (nilai default di bawah):
#   PG_CONTAINER   container PostgreSQL                     (postgres_dev)
#   PG_USER        user PostgreSQL                          (research_user)
#   PG_DB          database                                 (research_db)
#   SKRIP_DIR      folder t1-t6 di DALAM container          (/pgbench)
#   KLIEN          daftar jumlah klien untuk mode step      ("1 5 10 20 40 80")
#   DURASI         detik per tahap                          (120)
#   JEDA           detik jeda antar tahap                   (60)
#   THREADS        thread pgbench                           (2)
#   SOAK_KLIEN     klien untuk mode soak                    (24)
#   SOAK_DURASI    detik untuk mode soak                    (7200)
#   TEXTFILE_DIR   folder host yang dibaca node_exporter    (kosong = tidak kirim metrik)
#   GRAFANA_URL    URL Grafana                              (http://localhost:3000)
#   GRAFANA_TOKEN  token service account Grafana            (kosong = tanpa annotation)
#   SNAPSHOT       file dump di host (pg_dump -Fc). Bila diisi, database di-restore dan
#                  di-ANALYZE sebelum setiap tahap, supaya data hasil insert tahap sebelumnya
#                  tidak menambah volume tahap berikutnya. Sangat disarankan untuk matriks.
#   PGBENCH_LOKAL  isi 1 untuk memakai pgbench di host, bukan docker exec (untuk uji)
# =====================================================================
set -uo pipefail

MODE="${1:-}"
LABEL="${2:-uji}"
case "$MODE" in step|spike|laporan|soak) ;; *)
  echo "Pemakaian: $0 {step|spike|laporan|soak} <label>"; exit 1 ;;
esac

PG_CONTAINER="${PG_CONTAINER:-postgres_dev}"
PG_USER="${PG_USER:-research_user}"
PG_DB="${PG_DB:-research_db}"
SKRIP_DIR="${SKRIP_DIR:-/pgbench}"
KLIEN="${KLIEN:-1 5 10 20 40 80}"
DURASI="${DURASI:-120}"
JEDA="${JEDA:-60}"
THREADS="${THREADS:-2}"
SOAK_KLIEN="${SOAK_KLIEN:-24}"
SOAK_DURASI="${SOAK_DURASI:-7200}"
TEXTFILE_DIR="${TEXTFILE_DIR:-}"
GRAFANA_URL="${GRAFANA_URL:-http://localhost:3000}"
GRAFANA_TOKEN="${GRAFANA_TOKEN:-}"
PGBENCH_LOKAL="${PGBENCH_LOKAL:-}"
SNAPSHOT="${SNAPSHOT:-}"
if [ -n "$SNAPSHOT" ] && [ ! -f "$SNAPSHOT" ]; then echo "File SNAPSHOT tidak ditemukan: $SNAPSHOT"; exit 1; fi

OUT="$(pwd)/hasil/${LABEL}_${MODE}_$(date +%Y%m%d_%H%M)"
mkdir -p "$OUT"
WAKTU="$OUT/waktu.csv"
echo "tahap,klien,mulai,selesai,pendaftaran_awal,pelayanan_awal,pendaftaran_akhir,pelayanan_akhir" > "$WAKTU"

CAMPURAN=(-f "$SKRIP_DIR/t1_daftar.sql@25" -f "$SKRIP_DIR/t2_buka_rme.sql@30" -f "$SKRIP_DIR/t3_periksa.sql@20"
          -f "$SKRIP_DIR/t4_farmasi.sql@10" -f "$SKRIP_DIR/t5_bayar.sql@10" -f "$SKRIP_DIR/t6_laporan.sql@5")
TANPA_T6=(-f "$SKRIP_DIR/t1_daftar.sql@25" -f "$SKRIP_DIR/t2_buka_rme.sql@30" -f "$SKRIP_DIR/t3_periksa.sql@20"
          -f "$SKRIP_DIR/t4_farmasi.sql@10" -f "$SKRIP_DIR/t5_bayar.sql@10")
PAGI=(-f "$SKRIP_DIR/t1_daftar.sql@40" -f "$SKRIP_DIR/t2_buka_rme.sql@40" -f "$SKRIP_DIR/t3_periksa.sql@10"
      -f "$SKRIP_DIR/t5_bayar.sql@10")
HANYA_T6=(-f "$SKRIP_DIR/t6_laporan.sql")

pgb() {
  if [ -n "$PGBENCH_LOKAL" ]; then
    pgbench "$@" "$PG_DB"
  else
    docker exec -i "$PG_CONTAINER" pgbench -U "$PG_USER" "$@" "$PG_DB"
  fi
}

psql_db() {
  if [ -n "$PGBENCH_LOKAL" ]; then
    psql -q -d "$PG_DB" "$@"
  else
    docker exec -i "$PG_CONTAINER" psql -q -U "$PG_USER" -d "$PG_DB" "$@"
  fi
}

# Jumlah kunjungan dan pelayanan medis saat ini (untuk mencatat pertumbuhan data per tahap)
hitung_data() {
  psql_db -At -c "SELECT (SELECT count(*) FROM pendaftaran) || ',' || (SELECT count(*) FROM pelayanan_medis)"
}

# Kembalikan database ke kondisi snapshot, lalu perbarui statistik planner
pulihkan() {
  [ -z "$SNAPSHOT" ] && return 0
  echo "[$(date +%T)] restore snapshot $(basename "$SNAPSHOT")"
  if [ -n "$PGBENCH_LOKAL" ]; then
    pg_restore -d "$PG_DB" --clean --if-exists "$SNAPSHOT" || { echo "Restore gagal"; exit 1; }
  else
    docker exec -i "$PG_CONTAINER" pg_restore -U "$PG_USER" -d "$PG_DB" --clean --if-exists < "$SNAPSHOT" \
      || { echo "Restore gagal"; exit 1; }
  fi
  psql_db -c "ANALYZE;" -c "CHECKPOINT;" >/dev/null || { echo "ANALYZE gagal"; exit 1; }
}

anotasi() {  # $1 = teks
  echo "[$(date +%T)] $1"
  [ -z "$GRAFANA_TOKEN" ] && return 0
  curl -s -o /dev/null -X POST "$GRAFANA_URL/api/annotations" \
    -H "Authorization: Bearer $GRAFANA_TOKEN" -H "Content-Type: application/json" \
    -d "{\"time\": $(date +%s%3N), \"tags\": [\"stress-test\", \"$LABEL\"], \"text\": \"$LABEL $MODE: $1\"}" \
    || echo "  (annotation Grafana gagal dikirim, pengujian tetap jalan)"
}

# Jalankan satu pgbench; progress (-P 5) disalin ke log dan ke textfile collector.
# $1 nama tahap, $2 klien, $3 durasi, sisanya: daftar -f
jalankan() {
  local tahap="$1" klien="$2" durasi="$3"; shift 3
  local log="$OUT/${tahap}.log" prom="" mulai awal akhir selesai
  [ -n "$TEXTFILE_DIR" ] && prom="$TEXTFILE_DIR/pgbench_${tahap}.prom"
  awal="$(hitung_data)"
  mulai="$(date '+%Y-%m-%d %H:%M:%S')"
  # Baris progress contoh: "progress: 5.0 s, 935.2 tps, lat 10.689 ms stddev 5.123, 0 failed"
  local lbl="{skenario=\"$LABEL\",tahap=\"$tahap\",klien=\"$klien\"}"
  pgb -n -c "$klien" -j "$THREADS" -T "$durasi" -P 5 -r "$@" 2>&1 | tee "$log" | \
    while IFS= read -r baris; do
      [ -z "$prom" ] && continue
      case "$baris" in progress:*) ;; *) continue ;; esac
      read -r _ _ _ tps _ _ lat _ _ _ gagal _ <<< "${baris//,/}"
      printf 'pgbench_tps%s %s\npgbench_latency_ms%s %s\npgbench_failed%s %s\n' \
        "$lbl" "$tps" "$lbl" "$lat" "$lbl" "${gagal:-0}" > "$prom.tmp" && mv "$prom.tmp" "$prom"
    done
  [ -n "$prom" ] && rm -f "$prom"
  selesai="$(date '+%Y-%m-%d %H:%M:%S')"
  akhir="$(hitung_data)"
  echo "$tahap,$klien,$mulai,$selesai,$awal,$akhir" >> "$WAKTU"
  echo "    data (kunjungan,pelayanan): awal $awal -> akhir $akhir"
  grep -E "^tps|number of failed|latency average" "$log" | head -3 | sed 's/^/    /'
}

anotasi "mulai"
case "$MODE" in
  step)
    for c in $KLIEN; do
      pulihkan
      anotasi "$c klien"
      jalankan "klien_$c" "$c" "$DURASI" "${CAMPURAN[@]}"
      sleep "$JEDA"
    done ;;
  spike)
    # default DURASI=600: normal 5 menit, lonjakan 10 menit, pemulihan 5 menit, tanpa jeda
    pulihkan
    anotasi "normal 10 klien";    jalankan "spike_1_normal" 10 $(( DURASI / 2 )) "${CAMPURAN[@]}"
    anotasi "lonjakan 60 klien";  jalankan "spike_2_lonjak" 60 "$DURASI" "${PAGI[@]}"
    anotasi "pemulihan 10 klien"; jalankan "spike_3_pulih"  10 $(( DURASI / 2 )) "${CAMPURAN[@]}" ;;
  laporan)
    pulihkan
    anotasi "pelayanan 40 klien, laporan mulai menit ke-5"
    jalankan "laporan_pelayanan" 40 "$DURASI" "${TANPA_T6[@]}" &
    PID=$!
    sleep $(( DURASI / 2 ))
    anotasi "4 laporan berat paralel"
    jalankan "laporan_t6" 4 $(( DURASI / 3 )) "${HANYA_T6[@]}"
    wait "$PID" ;;
  soak)
    pulihkan
    anotasi "soak $SOAK_KLIEN klien"
    jalankan "soak" "$SOAK_KLIEN" "$SOAK_DURASI" "${CAMPURAN[@]}" ;;
esac
anotasi "selesai"

echo
echo "Hasil tersimpan di: $OUT"
echo "Waktu tiap tahap (untuk prom_export_csv.py): $WAKTU"
