from pathlib import Path
import json
import pandas as pd

BASE = Path(__file__).resolve().parent
DATA = BASE / "data"
OUT = BASE / "output"
OUT.mkdir(exist_ok=True)

TABLES = """Pegawai Administrasi Peg_Registrasi Peg_Rekam_Medis Peg_Keuangan Peg_Admisi_Pelayanan Tenaga_Medis Tenaga_Paramedis Dokter Perawat Laboran Radiografer Apoteker Koki Ahli_Gizi RME Pasien No_Telp_Pasien Alergi_RME Riwayat_Penyakit_RME Obat_Rutin_RME Imunisasi_RME Penjamin Daftar_Penjaminan Kontak_Penjamin Pendaftaran Klaim_Asuransi IGD Rawat_Jalan Pembayaran Admisi Unit_Layanan Layanan Tarif Penyediaan_Layanan Pelayanan_Medis Kelas_Ruangan Ruangan Ruangan_Rawat_Inap Tarif_Kelas Penempatan_Ruangan Jadwal_Dokter Penanganan_Medis Operasi Peran_Operasi Perawatan_Klinis Penunjang_Medis Laboratorium Radiologi Farmasi Gizi Obat Pemberian_Obat Entri_RME Entri_Pendaftaran Entri_Pelayanan Aktivitas_Penanganan Diagnosis""".split()

def val(x):
    if pd.isna(x):
        return None
    if hasattr(x, "item"):
        x = x.item()
    if isinstance(x, float) and x.is_integer():
        return int(x)
    return x

def load():
    data = {}
    for table in TABLES:
        p = DATA / f"{table.lower()}.csv"
        if not p.exists():
            p = DATA / f"{table}.csv"
        if p.exists():
            df = pd.read_csv(p, dtype=object)
            df.columns = [c.strip() for c in df.columns]
            data[table] = [{k: val(v) for k, v in r.items()}
                           for r in df.to_dict("records")]
            print(f"OK {table}: {len(data[table])} rows")
        else:
            data[table] = []
            print(f"SKIP {table}: CSV tidak ditemukan")
    return data

def index(rows, key):
    return {r.get(key): r for r in rows if r.get(key) is not None}

def grouped(rows, key):
    out = {}
    for r in rows:
        if r.get(key) is not None:
            out.setdefault(r[key], []).append(r)
    return out

def many(parent, children, pkey, ckey, field, omit=()):
    groups = grouped(children, ckey)
    for p in parent:
        p[field] = [{k:v for k,v in c.items() if k not in omit}
                    for c in groups.get(p.get(pkey), [])]

def one(parent, children, pkey, ckey, field, omit=()):
    lookup = index(children, ckey)
    for p in parent:
        c = lookup.get(p.get(pkey))
        p[field] = ({k:v for k,v in c.items() if k not in omit} if c else None)

def save(name, rows):
    with (OUT / f"{name}.json").open("w", encoding="utf-8") as f:
        json.dump(rows, f, ensure_ascii=False, indent=2)
    print(f"JSON {name}: {len(rows)} documents")

def main():
    t = load()

    # Gabungkan semua pegawai (subtipe nya juga)
    pegawai = [dict(x) for x in t["Pegawai"]]
    one(pegawai, t["Administrasi"], "id_pegawai", "id_pegawai", "administrasi", ("id_pegawai",))
    one(pegawai, t["Tenaga_Medis"], "id_pegawai", "id_pegawai", "tenaga_medis", ("id_pegawai",))
    one(pegawai, t["Tenaga_Paramedis"], "id_pegawai", "id_pegawai", "tenaga_paramedis", ("id_pegawai",))
    subtype = [
        ("Peg_Registrasi","administrasi","registrasi"),
        ("Peg_Rekam_Medis","administrasi","rekam_medis"),
        ("Peg_Keuangan","administrasi","keuangan"),
        ("Peg_Admisi_Pelayanan","administrasi","admisi_pelayanan"),
        ("Dokter","tenaga_medis","dokter"),
        ("Perawat","tenaga_medis","perawat"),
        ("Laboran","tenaga_paramedis","laboran"),
        ("Radiografer","tenaga_paramedis","radiografer"),
        ("Apoteker","tenaga_paramedis","apoteker"),
        ("Koki","tenaga_paramedis","koki"),
        ("Ahli_Gizi","tenaga_paramedis","ahli_gizi"),
    ]
    for table, parent_field, field in subtype:
        lookup = index(t[table], "id_pegawai")
        for p in pegawai:
            parent = p.get(parent_field)
            if parent:
                child = lookup.get(p["id_pegawai"])
                parent[field] = ({k:v for k,v in child.items() if k != "id_pegawai"}
                                 if child else None)

    # Pasien dan no.telp
    pasien = [dict(x) for x in t["Pasien"]]
    many(pasien, t["No_Telp_Pasien"], "nik_pasien", "nik_pasien",
         "nomor_telepon", ("nik_pasien",))

    # RME (beserta alergi, riwayat, obat, imunisasi)
    rme = [dict(x) for x in t["RME"]]
    for table, field, col in [
        ("Alergi_RME","alergi","alergi"),
        ("Riwayat_Penyakit_RME","riwayat_penyakit","riwayat_penyakit"),
        ("Obat_Rutin_RME","obat_rutin","obat_rutin"),
        ("Imunisasi_RME","imunisasi","imunisasi")]:
        g = grouped(t[table], "no_rm")
        for d in rme:
            d[field] = [x.get(col) for x in g.get(d.get("no_rm"), [])]

    # Penjamin + kontaknya
    penjamin = [dict(x) for x in t["Penjamin"]]
    many(penjamin, t["Kontak_Penjamin"], "id_penjamin", "id_penjamin",
         "kontak", ("id_penjamin",))

    # Layanan + tarifnya
    layanan = [dict(x) for x in t["Layanan"]]
    many(layanan, t["Tarif"], "id_layanan", "id_layanan",
         "tarif", ("id_layanan",))

    # Operasi dan peran2 di dalamnya
    operasi = [dict(x) for x in t["Operasi"]]
    many(operasi, t["Peran_Operasi"], "id_pelayanan_medis",
         "id_pelayanan_medis", "tim_operasi", ("id_pelayanan_medis",))

    # Pendaftaran + klaimnya
    pendaftaran = [dict(x) for x in t["Pendaftaran"]]
    many(pendaftaran, t["Klaim_Asuransi"], "no_registrasi",
         "no_registrasi", "klaim_asuransi", ("no_registrasi",))

    # Ruangan
    ruangan = [dict(x) for x in t["Ruangan"]]
    one(ruangan, t["Ruangan_Rawat_Inap"], "id_ruangan", "id_ruangan",
        "rawat_inap", ("id_ruangan",))

    # Penunjang Medis (Laboratorium, Radiologi, Farmasi, Gizi)
    penunjang = [dict(x) for x in t["Penunjang_Medis"]]
    for table, field in [("Laboratorium","laboratorium"),("Radiologi","radiologi"),
                         ("Farmasi","farmasi"),("Gizi","gizi")]:
        one(penunjang, t[table], "id_pelayanan_medis", "id_pelayanan_medis",
            field, ("id_pelayanan_medis",))

    collections = {
        "pegawai": pegawai,
        "pasien": pasien,
        "rme": rme,
        "penjamin": penjamin,
        "layanan": layanan,
        "operasi": operasi,
        "daftar_penjaminan": t["Daftar_Penjaminan"],
        "pendaftaran": pendaftaran,
        "igd": t["IGD"],
        "rawat_jalan": t["Rawat_Jalan"],
        "pembayaran": t["Pembayaran"],
        "admisi": t["Admisi"],
        "unit_layanan": t["Unit_Layanan"],
        "penyediaan_layanan": t["Penyediaan_Layanan"],
        "pelayanan_medis": t["Pelayanan_Medis"],
        "kelas_ruangan": t["Kelas_Ruangan"],
        "ruangan": ruangan,
        "tarif_kelas": t["Tarif_Kelas"],
        "penempatan_ruangan": t["Penempatan_Ruangan"],
        "jadwal_dokter": t["Jadwal_Dokter"],
        "penanganan_medis": t["Penanganan_Medis"],
        "perawatan_klinis": t["Perawatan_Klinis"],
        "penunjang_medis": penunjang,
        "laboratorium": t["Laboratorium"],
        "radiologi": t["Radiologi"],
        "farmasi": t["Farmasi"],
        "gizi": t["Gizi"],
        "obat": t["Obat"],
        "pemberian_obat": t["Pemberian_Obat"],
        "entri_rme": t["Entri_RME"],
        "entri_pendaftaran": t["Entri_Pendaftaran"],
        "entri_pelayanan": t["Entri_Pelayanan"],
        "aktivitas_penanganan": t["Aktivitas_Penanganan"],
        "diagnosis": t["Diagnosis"],
    }

    for name, rows in collections.items():
        save(name, rows)

    print("\\nSelesai. Hasil ada di folder output/.")
    print("Periksa jumlah dokumen dan contoh relasi sebelum import ke MongoDB.")

if __name__ == "__main__":
    main()