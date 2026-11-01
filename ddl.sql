-- Implementasi DDL di sini

CREATE TABLE IF NOT EXISTS Pasien(
    nik_pasien INT PRIMARY KEY,
    no_rm INT NOT NULL UNIQUE,
    nama_pasien VARCHAR(100)  NOT NULL,
    tanggal_lahir_pasien DATE NOT NULL,
    jenis_kelamin VARCHAR(1) NOT NULL CHECK (jenis_kelamin IN ('L', 'P')),
    jalan VARCHAR(150) NOT NULL,
    rt VARCHAR(5) NOT NULL,
    rw VARCHAR(5) NOT NULL,
    kota VARCHAR(50) NOT NULL,
    provinsi VARCHAR(50) NOT NULL,
    FOREIGN KEY (no_rm) REFERENCES RME(no_rm));

CREATE TABLE IF NOT EXISTS No_Telp_Pasien(
    nik_pasien INT NOT NULL,
    no_telp_pasien VARCHAR(20) NOT NULL,
    PRIMARY KEY (nik_pasien, no_telp_pasien),
    FOREIGN KEY (nik_pasien) REFERENCES Pasien(nik_pasien));

CREATE TABLE IF NOT EXISTS Daftar_Penjaminan(
    nik_pasien INT NOT NULL,
    id_penjamin INT NOT NULL,
    no_kartu INT,
    status VARCHAR(20) NOT NULL,
    PRIMARY KEY (nik_pasien, id_penjamin),
    FOREIGN KEY (nik_pasien) REFERENCES Pasien(nik_pasien),
    FOREIGN KEY (id_penjamin) REFERENCES Penjamin(id_penjamin));

CREATE TABLE IF NOT EXISTS Penjamin(
    id_penjamin INT PRIMARY KEY,
    nama_penjamin VARCHAR(100) NOT NULL,
    jenis_penjamin VARCHAR(50) NOT NULL,
    jalan VARCHAR(150) NOT NULL,
    rt VARCHAR(5) NOT NULL,
    rw VARCHAR(5) NOT NULL,
    kota VARCHAR(50) NOT NULL,
    provinsi VARCHAR(50) NOT NULL);

CREATE TABLE IF NOT EXISTS Kontak_Penjamin(
    id_penjamin INT NOT NULL,
    kontak VARCHAR(100) NOT NULL,
    PRIMARY KEY (id_penjamin, kontak),
    FOREIGN KEY (id_penjamin) REFERENCES Penjamin(id_penjamin));

CREATE TABLE IF NOT EXISTS Tarif(
    id_layanan INT NOT NULL,
    versi_harga VARCHAR(20) NOT NULL,
    harga NUMERIC(14,2) NOT NULL CHECK (harga >= 0),
    PRIMARY KEY (id_layanan, versi_harga),
    FOREIGN KEY (id_layanan) REFERENCES Layanan(id_layanan));

CREATE TABLE IF NOT EXISTS Klaim_Asuransi(
    id_asuransi INT PRIMARY KEY,
    laporan_rumah_sakit TEXT,
    rincian_klaim_asuransi TEXT,
    no_registrasi INT NOT NULL,
    FOREIGN KEY (no_registrasi) REFERENCES Pendaftaran(no_registrasi));

CREATE TABLE IF NOT EXISTS Pendaftaran(
    no_registrasi INT PRIMARY KEY,
    tanggal_daftar DATE NOT NULL,
    jam_daftar TIME NOT NULL,
    jenis_tindakan VARCHAR(50) NOT NULL CHECK (jenis_tindakan IN ('IGD', 'Rawat_Jalan')),
    hasil_penanganan TEXT,
    nik_pasien INT NOT NULL,
    id_penjamin INT NOT NULL,
    id_pegawai INT NOT NULL,
    FOREIGN KEY (nik_pasien, id_penjamin) REFERENCES Daftar_Penjaminan(nik_pasien, id_penjamin),
    FOREIGN KEY (id_pegawai) REFERENCES Peg_Registrasi(id_pegawai));

CREATE TABLE IF NOT EXISTS IGD(
    no_registrasi INT PRIMARY KEY,
    FOREIGN KEY (no_registrasi) REFERENCES Pendaftaran(no_registrasi));

CREATE TABLE IF NOT EXISTS Rawat_Jalan(
    no_registrasi INT PRIMARY KEY,
    FOREIGN KEY (no_registrasi) REFERENCES Pendaftaran(no_registrasi));

CREATE TABLE IF NOT EXISTS Pembayaran(
    no_billing INT PRIMARY KEY,
    tanggal_pembayaran DATE NOT NULL,
    waktu_pembayaran TIME NOT NULL,
    metode_pembayaran VARCHAR(30) NOT NULL CHECK (metode_pembayaran IN ('Tunai', 'Non-Tunai')),
    status_pembayaran VARCHAR(20) NOT NULL CHECK (status_pembayaran IN ('Berhasil', 'Gagal')),
    id_pegawai INT NOT NULL,
    no_registrasi INT NOT NULL,
    jumlah_pembayaran NUMERIC(14,2) NOT NULL CHECK (jumlah_pembayaran >= 0),
    FOREIGN KEY (id_pegawai) REFERENCES Peg_Keuangan(id_pegawai),
    FOREIGN KEY (no_registrasi) REFERENCES Pendaftaran(no_registrasi));

CREATE TABLE IF NOT EXISTS Admisi(
    no_registrasi INT PRIMARY KEY,
    jenis_upgrade INT,
    catatan_admisi TEXT,
    id_pegawai INT NOT NULL,
    FOREIGN KEY (no_registrasi) REFERENCES Pendaftaran(no_registrasi),
    FOREIGN KEY (id_pegawai) REFERENCES Peg_Admisi_Pelayanan(id_pegawai));

CREATE TABLE IF NOT EXISTS Penempatan_Ruangan(
    no_registrasi INT NOT NULL,
    waktu_masuk TIMESTAMP NOT NULL,
    id_ruangan INT NOT NULL,
    waktu_keluar TIMESTAMP,
    PRIMARY KEY (no_registrasi, waktu_masuk), CHECK (waktu_keluar IS NULL OR waktu_keluar >= waktu_masuk),
    FOREIGN KEY (no_registrasi) REFERENCES Admisi(no_registrasi),
    FOREIGN KEY (id_ruangan) REFERENCES Ruangan_Rawat_Inap(id_ruangan));

CREATE TABLE IF NOT EXISTS Ruangan(
    id_ruangan INT PRIMARY KEY,
    nama_ruangan VARCHAR(100) NOT NULL,
    kapasitas_ruangan INT NOT NULL CHECK (kapasitas_ruangan > 0),
    status_ruangan VARCHAR(20) NOT NULL CHECK (status_ruangan IN ('Penuh', 'Tersedia')),
    id_unit INT NOT NULL,
    FOREIGN KEY (id_unit) REFERENCES Unit_Layanan(id_unit));

CREATE TABLE IF NOT EXISTS Ruangan_Rawat_Inap(
    id_ruangan INT PRIMARY KEY,
    id_kelas INT NOT NULL,
    FOREIGN KEY (id_ruangan) REFERENCES Ruangan(id_ruangan),
    FOREIGN KEY (id_kelas) REFERENCES Kelas_Ruangan(id_kelas));

CREATE TABLE IF NOT EXISTS Kelas_Ruangan(
    id_kelas INT PRIMARY KEY,
    nama_kelas VARCHAR(50) NOT NULL);

CREATE TABLE IF NOT EXISTS Tarif_Kelas(
    id_kelas INT NOT NULL,
    versi_harga VARCHAR(20) NOT NULL,
    harga_per_malam NUMERIC(14,2) NOT NULL CHECK (harga_per_malam >= 0),
    berlaku_dari DATE NOT NULL,
    berlaku_sampai DATE CHECK (berlaku_sampai IS NULL OR berlaku_sampai >= berlaku_dari),
    PRIMARY KEY (id_kelas, versi_harga),
    FOREIGN KEY (id_kelas) REFERENCES Kelas_Ruangan(id_kelas));

CREATE TABLE IF NOT EXISTS Unit_Layanan(
    id_unit INT PRIMARY KEY,
    ruang_unit VARCHAR(100) NOT NULL,
    departemen VARCHAR(100) NOT NULL);

CREATE TABLE IF NOT EXISTS Penyediaan_Layanan(
    id_unit INT NOT NULL,
    id_layanan INT NOT NULL,
    PRIMARY KEY (id_unit, id_layanan),
    FOREIGN KEY (id_unit) REFERENCES Unit_Layanan(id_unit),
    FOREIGN KEY (id_layanan) REFERENCES Layanan(id_layanan));

CREATE TABLE IF NOT EXISTS Layanan(
    id_layanan INT PRIMARY KEY,
    nama_layanan VARCHAR(100) NOT NULL,
    kategori VARCHAR(50) NOT NULL,
    deskripsi TEXT);

CREATE TABLE IF NOT EXISTS Entri_RME(
    id_entri INT PRIMARY KEY,
    waktu_entri TIMESTAMP NOT NULL,
    isi_entri TEXT NOT NULL,
    id_pegawai INT NOT NULL,
    FOREIGN KEY (id_pegawai) REFERENCES Pegawai(id_pegawai));

CREATE TABLE IF NOT EXISTS Entri_Pendaftaran(
    id_entri INT PRIMARY KEY,
    no_registrasi INT NOT NULL,
    FOREIGN KEY (id_entri) REFERENCES Entri_RME(id_entri),
    FOREIGN KEY (no_registrasi) REFERENCES Pendaftaran(no_registrasi));

CREATE TABLE IF NOT EXISTS Entri_Pelayanan(
    id_entri INT PRIMARY KEY,
    id_pelayanan_medis INT NOT NULL,
    FOREIGN KEY (id_entri) REFERENCES Entri_RME(id_entri),
    FOREIGN KEY (id_pelayanan_medis) REFERENCES Pelayanan_Medis(id_pelayanan_medis));

CREATE TABLE IF NOT EXISTS RME(
    no_rm INT PRIMARY KEY,
    id_pegawai INT NOT NULL,
    FOREIGN KEY (id_pegawai) REFERENCES Peg_Rekam_Medis(id_pegawai));

CREATE TABLE IF NOT EXISTS Alergi_RME(
    no_rm INT NOT NULL,
    alergi VARCHAR(100) NOT NULL,
    PRIMARY KEY (no_rm, alergi),
    FOREIGN KEY (no_rm) REFERENCES RME(no_rm));

CREATE TABLE IF NOT EXISTS Riwayat_Penyakit_RME(
    no_rm INT NOT NULL,
    riwayat_penyakit VARCHAR(200) NOT NULL,
    PRIMARY KEY (no_rm, riwayat_penyakit),
    FOREIGN KEY (no_rm) REFERENCES RME(no_rm));

CREATE TABLE IF NOT EXISTS Obat_Rutin_RME(
    no_rm INT NOT NULL,
    obat_rutin VARCHAR(100) NOT NULL,
    PRIMARY KEY (no_rm, obat_rutin),
    FOREIGN KEY (no_rm) REFERENCES RME(no_rm));

CREATE TABLE IF NOT EXISTS Imunisasi_RME(
    no_rm INT NOT NULL,
    imunisasi VARCHAR(100) NOT NULL,
    PRIMARY KEY (no_rm, imunisasi),
    FOREIGN KEY (no_rm) REFERENCES RME(no_rm));

CREATE TABLE IF NOT EXISTS Pelayanan_Medis(
    id_pelayanan_medis INT PRIMARY KEY,
    waktu_mulai TIMESTAMP NOT NULL,
    waktu_selesai TIMESTAMP CHECK (waktu_selesai IS NULL OR waktu_selesai >= waktu_mulai),
    no_registrasi INT NOT NULL,
    id_layanan INT NOT NULL,
    versi_harga VARCHAR(20) NOT NULL,
    id_unit INT NOT NULL,
    FOREIGN KEY (no_registrasi) REFERENCES Pendaftaran(no_registrasi),
    FOREIGN KEY (id_layanan, versi_harga) REFERENCES Tarif(id_layanan, versi_harga),
    FOREIGN KEY (id_unit, id_layanan) REFERENCES Penyediaan_Layanan(id_unit, id_layanan));

CREATE TABLE IF NOT EXISTS Penanganan_Medis(
    id_pelayanan_medis INT PRIMARY KEY,
    id_pegawai INT NOT NULL,
    id_pegawai_peminta INT,
    id_jadwal INT,
    FOREIGN KEY (id_pelayanan_medis) REFERENCES Pelayanan_Medis(id_pelayanan_medis),
    FOREIGN KEY (id_pegawai) REFERENCES Dokter(id_pegawai),
    FOREIGN KEY (id_pegawai_peminta) REFERENCES Dokter(id_pegawai),
    FOREIGN KEY (id_jadwal) REFERENCES Jadwal_Dokter(id_jadwal));

CREATE TABLE IF NOT EXISTS Operasi(
    id_pelayanan_medis INT PRIMARY KEY,
    jenis_operasi VARCHAR(100) NOT NULL,
    ruang_operasi VARCHAR(50) NOT NULL,
    tanggal_waktu_operasi TIMESTAMP NOT NULL,
    hasil_operasi TEXT,
    FOREIGN KEY (id_pelayanan_medis) REFERENCES Pelayanan_Medis(id_pelayanan_medis));

CREATE TABLE IF NOT EXISTS Peran_Operasi(
    id_pelayanan_medis INT NOT NULL,
    id_pegawai INT NOT NULL,
    peran VARCHAR(50)  NOT NULL,
    PRIMARY KEY (id_pelayanan_medis, id_pegawai),
    FOREIGN KEY (id_pelayanan_medis) REFERENCES Operasi(id_pelayanan_medis),
    FOREIGN KEY (id_pegawai) REFERENCES Tenaga_Medis(id_pegawai));

CREATE TABLE IF NOT EXISTS Perawatan_Klinis(
    id_pelayanan_medis INT PRIMARY KEY,
    jenis_perawatan VARCHAR(100) NOT NULL,
    catatan_perawatan TEXT,
    id_pegawai INT NOT NULL,
    FOREIGN KEY (id_pelayanan_medis) REFERENCES Pelayanan_Medis(id_pelayanan_medis),
    FOREIGN KEY (id_pegawai) REFERENCES Perawat(id_pegawai));

CREATE TABLE IF NOT EXISTS Penunjang_Medis(
    id_pelayanan_medis INT PRIMARY KEY,
    laporan_penunjang_medis TEXT,
    tanggal_permintaan DATE NOT NULL,
    status_kebutuhan VARCHAR(30) NOT NULL,
    id_pegawai_medis INT NOT NULL,
    id_pegawai_paramedis INT,
    FOREIGN KEY (id_pelayanan_medis) REFERENCES Pelayanan_Medis(id_pelayanan_medis),
    FOREIGN KEY (id_pegawai_medis) REFERENCES Tenaga_Medis(id_pegawai),
    FOREIGN KEY (id_pegawai_paramedis) REFERENCES Tenaga_Paramedis(id_pegawai));

CREATE TABLE IF NOT EXISTS Laboratorium(
    id_pelayanan_medis INT PRIMARY KEY,
    nama_laboratorium VARCHAR(100) NOT NULL,
    jenis_pemeriksaan VARCHAR(100) NOT NULL,
    hasil_laboratorium TEXT,
    id_pegawai INT NOT NULL,
    FOREIGN KEY (id_pelayanan_medis) REFERENCES Penunjang_Medis(id_pelayanan_medis),
    FOREIGN KEY (id_pegawai) REFERENCES Laboran(id_pegawai));

CREATE TABLE IF NOT EXISTS Radiologi(
    id_pelayanan_medis INT PRIMARY KEY,
    nama_ruang_radiologi VARCHAR(100) NOT NULL,
    jenis_pemeriksaan_radiologi VARCHAR(100) NOT NULL,
    hasil_radiologi TEXT,
    id_pegawai INT NOT NULL,
    FOREIGN KEY (id_pelayanan_medis) REFERENCES Penunjang_Medis(id_pelayanan_medis),
    FOREIGN KEY (id_pegawai) REFERENCES Radiografer(id_pegawai));

CREATE TABLE IF NOT EXISTS Farmasi(
    id_pelayanan_medis INT PRIMARY KEY,
    laporan_transaksi_obat TEXT,
    id_pegawai INT NOT NULL,
    FOREIGN KEY (id_pelayanan_medis) REFERENCES Penunjang_Medis(id_pelayanan_medis),
    FOREIGN KEY (id_pegawai) REFERENCES Apoteker(id_pegawai));

CREATE TABLE IF NOT EXISTS Pemberian_Obat(
    id_pelayanan_medis INT NOT NULL,
    no_obat INT NOT NULL,
    jumlah INT NOT NULL CHECK (jumlah > 0),
    PRIMARY KEY (id_pelayanan_medis, no_obat),
    FOREIGN KEY (id_pelayanan_medis) REFERENCES Farmasi(id_pelayanan_medis),
    FOREIGN KEY (no_obat) REFERENCES Obat(no_obat));

CREATE TABLE IF NOT EXISTS Obat(
    no_obat INT PRIMARY KEY,
    dosis_obat VARCHAR(50),
    produsen_obat VARCHAR(100),
    deskripsi_obat TEXT);

CREATE TABLE IF NOT EXISTS Gizi(
    id_pelayanan_medis INT PRIMARY KEY,
    nama_dapur VARCHAR(100) NOT NULL,
    jenis_diet VARCHAR(100) NOT NULL,
    kapasitas_porsi INT NOT NULL CHECK (kapasitas_porsi > 0),
    id_pegawai INT NOT NULL,
    id_pegawai_koki INT NOT NULL,
    FOREIGN KEY (id_pelayanan_medis) REFERENCES Penunjang_Medis(id_pelayanan_medis),
    FOREIGN KEY (id_pegawai) REFERENCES Ahli_Gizi(id_pegawai),
    FOREIGN KEY (id_pegawai_koki) REFERENCES Koki(id_pegawai));

CREATE TABLE IF NOT EXISTS Jadwal_Dokter(
    id_jadwal INT PRIMARY KEY,
    hari VARCHAR(10) NOT NULL,
    jam_mulai TIME NOT NULL,
    jam_selesai TIME NOT NULL CHECK (jam_selesai > jam_mulai),
    kuota INT NOT NULL CHECK (kuota >= 0),
    id_pegawai INT NOT NULL,
    id_unit INT NOT NULL,
    FOREIGN KEY (id_pegawai) REFERENCES Dokter(id_pegawai),
    FOREIGN KEY (id_unit) REFERENCES Unit_Layanan(id_unit));

CREATE TABLE IF NOT EXISTS Pegawai(
    id_pegawai INT PRIMARY KEY,
    nip INT NOT NULL UNIQUE,
    nama VARCHAR(100) NOT NULL,
    surat_pengangkatan VARCHAR(100));

CREATE TABLE IF NOT EXISTS Administrasi(
    id_pegawai INT PRIMARY KEY,
    bagian VARCHAR(50) NOT NULL,
    FOREIGN KEY (id_pegawai) REFERENCES Pegawai(id_pegawai));

CREATE TABLE IF NOT EXISTS Peg_Registrasi(
    id_pegawai INT PRIMARY KEY,
    loket_pendaftaran VARCHAR(50) NOT NULL,
    FOREIGN KEY (id_pegawai) REFERENCES Administrasi(id_pegawai));

CREATE TABLE IF NOT EXISTS Peg_Rekam_Medis(
    id_pegawai INT PRIMARY KEY,
    sertifikasi VARCHAR(100),
    FOREIGN KEY (id_pegawai) REFERENCES Administrasi(id_pegawai));

CREATE TABLE IF NOT EXISTS Peg_Keuangan(
    id_pegawai INT PRIMARY KEY,
    loket_pembayaran VARCHAR(50) NOT NULL,
    FOREIGN KEY (id_pegawai) REFERENCES Administrasi(id_pegawai));

CREATE TABLE IF NOT EXISTS Peg_Admisi_Pelayanan(
    id_pegawai INT PRIMARY KEY,
    jenis_pelayanan VARCHAR(50) NOT NULL,
    FOREIGN KEY (id_pegawai) REFERENCES Administrasi(id_pegawai));

CREATE TABLE IF NOT EXISTS Tenaga_Medis(
    id_pegawai INT PRIMARY KEY,
    no_str INT NOT NULL UNIQUE,
    no_sip INT NOT NULL UNIQUE,
    FOREIGN KEY (id_pegawai) REFERENCES Pegawai(id_pegawai));

CREATE TABLE IF NOT EXISTS Dokter(
    id_pegawai INT PRIMARY KEY,
    spesialisasi VARCHAR(100) NOT NULL,
    FOREIGN KEY (id_pegawai) REFERENCES Tenaga_Medis(id_pegawai));

CREATE TABLE IF NOT EXISTS Perawat(
    id_pegawai INT PRIMARY KEY,
    tingkatan VARCHAR(50) NOT NULL,
    FOREIGN KEY (id_pegawai) REFERENCES Tenaga_Medis(id_pegawai));

CREATE TABLE IF NOT EXISTS Tenaga_Paramedis(
    id_pegawai INT PRIMARY KEY,
    no_str INT NOT NULL UNIQUE,
    bidang VARCHAR(100) NOT NULL,
    sertifikasi VARCHAR(100),
    FOREIGN KEY (id_pegawai) REFERENCES Pegawai(id_pegawai));

CREATE TABLE IF NOT EXISTS Laboran(
    id_pegawai INT PRIMARY KEY,
    keahlian VARCHAR(100) NOT NULL,
    FOREIGN KEY (id_pegawai) REFERENCES Tenaga_Paramedis(id_pegawai));

CREATE TABLE IF NOT EXISTS Radiografer(
    id_pegawai INT PRIMARY KEY,
    keahlian VARCHAR(100) NOT NULL,
    FOREIGN KEY (id_pegawai) REFERENCES Tenaga_Paramedis(id_pegawai));

CREATE TABLE IF NOT EXISTS Apoteker(
    id_pegawai INT PRIMARY KEY,
    no_sipa INT NOT NULL UNIQUE,
    FOREIGN KEY (id_pegawai) REFERENCES Tenaga_Paramedis(id_pegawai));

CREATE TABLE IF NOT EXISTS Koki(
    id_pegawai INT PRIMARY KEY,
    keahlian VARCHAR(100) NOT NULL,
    FOREIGN KEY (id_pegawai) REFERENCES Tenaga_Paramedis(id_pegawai));

CREATE TABLE IF NOT EXISTS Ahli_Gizi(
    id_pegawai INT PRIMARY KEY,
    keahlian VARCHAR(100) NOT NULL,
    FOREIGN KEY (id_pegawai) REFERENCES Tenaga_Paramedis(id_pegawai));

CREATE TABLE IF NOT EXISTS Aktivitas_Penanganan(
    id_pelayanan_medis INT NOT NULL,
    no_aktivitas INT NOT NULL,
    jenis_aktivitas VARCHAR(100) NOT NULL,
    waktu_mulai TIMESTAMP NOT NULL,
    waktu_selesai TIMESTAMP CHECK (waktu_selesai IS NULL OR waktu_selesai >= waktu_mulai),
    catatan_aktivitas TEXT,
    PRIMARY KEY (id_pelayanan_medis, no_aktivitas),
    FOREIGN KEY (id_pelayanan_medis) REFERENCES Penanganan_Medis(id_pelayanan_medis));

CREATE TABLE IF NOT EXISTS Diagnosis(
    id_diagnosis INT PRIMARY KEY,
    kode_diagnosis VARCHAR(20) NOT NULL,
    deskripsi_diagnosis TEXT,
    jenis_diagnosis VARCHAR(30)   NOT NULL,
    waktu_diagnosis TIMESTAMP NOT NULL,
    id_pelayanan_medis INT NOT NULL,
    no_aktivitas INT NOT NULL,
    FOREIGN KEY (id_pelayanan_medis, no_aktivitas) REFERENCES Aktivitas_Penanganan(id_pelayanan_medis, no_aktivitas));
