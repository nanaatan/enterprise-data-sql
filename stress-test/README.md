# Skrip pgbench — simulasi beban rumah sakit

| File | Transaksi | Aktor | Bobot |
|---|---|---|---|
| `t1_daftar.sql` | Pendaftaran pasien (Rawat Jalan 90% / IGD 10%) | Registrasi | 25 |
| `t2_buka_rme.sql` | Buka RME + 10 diagnosis terakhir | Dokter/perawat | 30 |
| `t3_periksa.sql` | Pelayanan, penanganan, 3 aktivitas, 1–2 diagnosis | Dokter | 20 |
| `t4_farmasi.sql` | Penunjang medis, farmasi, 3 obat | Apoteker | 10 |
| `t5_bayar.sql` | Rincian tagihan + pembayaran | Kasir | 10 |
| `t6_laporan.sql` | Salah satu dari 3 laporan bulanan (acak) | Manajemen | 5 |

Butuh pgbench PostgreSQL 11 ke atas (memakai `\gset` dan `\if`).

## Asumsi seed data

Skrip memilih id secara acak, jadi seed data harus mengikuti rentang ini:

| Data | Rentang |
|---|---|
| Pegawai | id 1–500 |
| Peg_Registrasi | 1–40 |
| Peg_Rekam_Medis | 41–65 |
| Peg_Keuangan (kasir) | 66–95 |
| Peg_Admisi_Pelayanan | 96–120 |
| Dokter | 121–190 |
| Perawat | 191–350 |
| Laboran / Radiografer / Apoteker / Koki / Ahli Gizi | 351–380 / 381–395 / 396–420 / 421–450 / 451–470 |
| Pasien / RME | no_rm 1 sampai jumlah pasien (dibaca otomatis oleh T1 dan T2 dari `max(no_rm)`) |
| Obat | no_obat 1–2.000 |
| Periode data | 1-31 Oktober 2026 (T6 memakai periode 7 hari acak di dalamnya) |

Syarat lain:
- Setiap pasien punya minimal 1 baris di `daftar_penjaminan`.
- Setiap `id_layanan` di `penyediaan_layanan` punya minimal 1 baris di `tarif`.
- Kode diagnosis di seed memakai formula yang sama dengan T3:
  `chr(65 + n % 26) || lpad((n / 26)::text, 2, '0')` untuk n = 1..1500.

## Menjalankan

Satu transaksi saja (uji cepat):

```bash
pgbench -n -c 10 -j 2 -T 60 -f t2_buka_rme.sql nama_db
```

Campuran semua transaksi:

```bash
pgbench -n -c 50 -j 4 -T 600 -P 10 -r \
  -f t1_daftar.sql@25 -f t2_buka_rme.sql@30 -f t3_periksa.sql@20 \
  -f t4_farmasi.sql@10 -f t5_bayar.sql@10 -f t6_laporan.sql@5 nama_db
```

Skenario lengkap lewat `jalankan_uji.sh` (pgbench dijalankan di container `postgres_dev`):

```bash
chmod +x jalankan_uji.sh
SNAPSHOT=~/stress-test/snapshot_V1.dump ./jalankan_uji.sh step V1_tanpa_index   # 1, 5, 10, 20, 40, 80 klien x 2 menit
SNAPSHOT=~/stress-test/snapshot_V2.dump ./jalankan_uji.sh step V2_tanpa_index
KLIEN=20 ./jalankan_uji.sh step V2_dengan_index   # perbandingan index (tanpa SNAPSHOT, index sudah dibuat)
```

Dengan `SNAPSHOT`, database di-restore dan di-ANALYZE sebelum setiap tahap, sehingga setiap jumlah klien
diuji pada volume data yang sama. Pengaturan lain (container, user, database, durasi, folder textfile, token Grafana) ada di bagian
atas `jalankan_uji.sh` dan bisa diubah lewat environment variable. Hasil tiap pengujian tersimpan di
`hasil/<label>_<mode>_<waktu>/`, termasuk `waktu.csv` berisi jam mulai dan selesai tiap tahap serta jumlah kunjungan dan pelayanan
medis di awal dan akhir tahap. Transaksi T1, T3, dan T4 menambah data selama pengujian, jadi
angka ini dipakai untuk melaporkan berapa besar volume bertambah di dalam satu tahap.

File pendukung:
- `explain_baseline.sql` — rencana eksekusi query T2, T5, T6 dengan parameter tetap (fase 2 dan 6)
- `index_optimasi.sql` — kandidat index untuk fase optimasi

Opsi `-r` menampilkan latensi per statement di akhir log, berguna untuk menemukan query yang lambat.
