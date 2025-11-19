# kk – Kubernetes Power Helper CLI

![kk logo](logo.png)

## kubectl

`kk` คือ Bash wrapper ขนาดเล็กสำหรับ `kubectl` ที่ช่วยลดการพิมพ์คำสั่งซ้ำๆ และทำให้การแก้ปัญหาประจำวันเร็วขึ้น ทุกอย่างทำงานบนเครื่องของคุณ (ไม่มี CRD ไม่มีการติดตั้งบนคลัสเตอร์) และจะใช้ namespace ปัจจุบันของคุณให้อัตโนมัติ

## ทำไมต้องมี CLI อีกตัว?

การใช้ `kubectl` ตรงๆ มักต้องพิมพ์คำสั่งยาว ใส่ namespace เดิมซ้ำๆ และเลือก pod หรือ deployment เอง `kk` จึงเน้นว่า:

- คำสั่งย่อยสั้นๆ จำง่าย
- ช่วยจับคู่ชื่อ pod/deployment แบบฉลาด
- ทำงานที่ใช้บ่อย เช่น tail log, port-forward, restart ได้เร็ว
- ค่าเริ่มต้นแบบปลอดภัย (เช่น เก็บ namespace ที่ `~/.kk`) และเอาต์พุตสไตล์ Unix

ถ้าคุณคุ้นกับ `kubectl` อยู่แล้ว `kk` จะช่วยให้พิมพ์น้อยลงโดยยังได้พฤติกรรมเดิม

## ฟีเจอร์

- ผู้ช่วย namespace (`kk ns show|set`) เก็บค่าที่ `~/.kk`
- ยูทิลิตี้เกี่ยวกับ pod และ service: list, exec shell, logs, describe, port-forward
- เครื่องมือแก้ปัญหา: log หลาย pod, กรอง `kubectl top`, ดู events ล่าสุด
- งาน deployment: restart รวดเร็วและสรุปสถานะให้อ่านง่าย (ถ้ามี `jq`)
- จัดการ context (`kk ctx`) เพื่อสลับ context โดยไม่แตะ namespace

## kk ช่วยประหยัดเวลาอย่างไร

- **จำ namespace ให้อัตโนมัติ** – `kk ns set` เก็บชื่อ namespace ลงใน `~/.kk` แล้วทุกคำสั่งจะใส่ `-n "$NAMESPACE"` ให้เอง ไม่ต้องพิมพ์ซ้ำ
- **เลือก resource ด้วย pattern ก่อนเสมอ** – คำสั่งอย่าง `kk sh`, `kk desc`, `kk restart` ใช้ selector ชุดเดียวกันในการกรองด้วย regex และถ้าชนหลายรายการก็เปิด `fzf --height=40% --border` ให้เลือกทันที
- **tail logs หลาย pod พร้อมกัน** – `kk logs` เปิด `kubectl logs` แบบ background ให้ทุก pod ใส่ prefix ชื่อ pod ให้อ่านง่าย พร้อมตัวเลือก `-g/--grep` และ `-f/--follow` เหมือนเดิม
- **⭐️ ดีบั๊ก deployment ที่มีหลาย replica ได้ทีเดียว** – เวลาอยากหา log จากงานที่ scale เช่น `api` เพียงพิมพ์ `kk logs api -g "traceId=123"` แล้วมันจะดึงทุก replica มาพร้อมกัน พร้อม prefix ชื่อ pod ให้เห็นชัดว่าแถวไหนมาจากตัวไหน ไม่ต้องคัดลอกชื่อ pod ทีละตัวหรือวน `kubectl logs` เองอีกต่อไป
- **บอกข้อผิดพลาดอย่างชัดเจน** – `kk pf` แจ้งสาเหตุ port-forward พัง, `kk ctx` รายงานผลการสลับ context, ส่วน `kk restart` ระบุ deployment เป้าหมายชัดเจนก่อนยิงคำสั่งจริง

## ความต้องการระบบ

- Bash 4+
- `kubectl` ที่ตั้งค่าเชื่อมต่อคลัสเตอร์ของคุณแล้ว
- เสริม (ไม่บังคับ):
  - `jq` เพื่อเอาต์พุตที่อ่านง่ายขึ้นใน `kk images` และ `kk deploys`
  - `fzf` สำหรับเลือก resource แบบ interactive เมื่อมีหลายรายการ

## การติดตั้ง

### สร้าง symlink เอง

```bash
git clone git@github.com:heart/kk-Kubernetes-Power-Helper-CLI.git
cd kk-Kubernetes-Power-Helper-CLI
chmod +x kk
ln -s "$(pwd)/kk" /usr/local/bin/kk  # ปรับ path ตามต้องการ
```

หรือคัดลอกไฟล์ `kk` ไปไว้ที่ใดก็ได้บน `PATH` ของคุณ

### install-kk.sh (รองรับออฟไลน์)

โคลน (หรือคัดลอก) repo นี้ไปยังเครื่องที่เข้าถึงโฮสต์ปลายทางได้ แล้วรัน:

```bash
cd kk-Kubernetes-Power-Helper-CLI
sudo bash install-kk.sh                              # ดาวน์โหลด kk ล่าสุดจาก GitHub
sudo KK_URL="$(pwd)/kk" bash install-kk.sh           # ใช้ไฟล์ kk ใน repo สำหรับติดตั้งออฟไลน์
sudo INSTALL_PATH=/opt/bin/kk bash install-kk.sh     # กำหนด path ปลายทางเอง
```

ตั้งค่า `KK_URL` ให้เป็น path ภายใน เช่น `sudo KK_URL="$(pwd)/kk" …` หรือใช้รูปแบบ `file:///path/to/kk` เมื่อเครื่องเป้าหมายออฟไลน์

### install-kk.sh แบบ one-liner

```bash
curl -fsSL https://raw.githubusercontent.com/heart/kk-Kubernetes-Power-Helper-CLI/main/install-kk.sh | sudo bash
```

สามารถตั้ง `INSTALL_PATH` หรือ `KK_URL` เป็น environment variables ก่อนคำสั่งนี้ได้ หากต้องการ path หรือ mirror เฉพาะ

> หมายเหตุ: โค้ดชุดนี้ถูกสร้างและดูแลด้วยความช่วยเหลือจาก Codex agent—กรุณารีวิวก่อนใช้งานกับคลัสเตอร์จริง

## เริ่มต้นใช้งาน

1. กำหนด namespace เริ่มต้นครั้งเดียว:
   ```bash
   kk ns set my-namespace
   ```
   ค่านี้จะถูกเก็บไว้ที่ `~/.kk`
2. ตรวจสอบ pod ใน namespace นั้น:
   ```bash
   kk pods
   kk pods api
   ```
3. tail log หรือเข้า shell ด้วย pattern แบบ regex:
   ```bash
   kk logs api -f -g ERROR
   kk sh api -- /bin/bash
   ```

## ⭐️⭐️⭐️ Pattern Matching ที่ใช้งานจริง ⭐️⭐️⭐️

- **Regex ได้ทุกที่** – อาร์กิวเมนต์ `<pattern>` ทุกจุดถูกมองเป็น regex ทำงานผ่าน `awk`/`grep` จะพิมพ์สั้นๆ (`api`) หรือ regex เต็ม (`^api-[0-9]+`) ก็ใช้ได้กับ pod, deployment, service โดยไม่ต้องจำ syntax ใหม่
- **บังคับให้เจอเป้าหมายเดียว** – ฟังก์ชัน `select_pod_by_pattern` และ `select_deploy_by_pattern` จะหาทรัพยากรให้เหลือหนึ่งรายการ ถ้ามีหลายตัว `kk` จะเปิด `fzf --height=40% --border` (ถ้าติดตั้งไว้) หรือแสดงรายการพร้อมเลขให้เลือก
- **ทำงานได้เร็วขึ้น** – ใช้แค่ `kk logs api` ก็ได้ผลลัพธ์ครบเหมือน `kubectl` และยังลดการพิมพ์ `grep`, loop, หรือ `-n` ซ้ำๆ
- **ลดความเสี่ยง** – เมื่อมีหลายรายการ คุณต้องเลือกชัดเจนก่อน `kk restart web` จะทำงาน จึงลดโอกาสยิงโดน deployment ผิดตัว

```bash
kk pods '^api-'
kk logs '^api-' -f -g ERROR
kk restart '^api-web'
```

regex สั้นๆ สามบรรทัดนี้ทำได้ทั้ง list, tail logs, และ restart โดยไม่ต้อง copy/paste ชื่อ pod เลย

## คำสั่งเด่น

| คำสั่ง                           | คำอธิบาย                                                              |
| -------------------------------- | --------------------------------------------------------------------- |
| `kk ns [show\|set\|list]`        | แสดง/ตั้งค่า namespace หรือเลือกผ่าน `fzf` แล้วบันทึกไว้ใน `~/.kk`    |
| `kk svc [pattern]`               | แสดง service พร้อมหัวตาราง จะใส่ regex เพื่อกรองชื่อได้               |
| `kk pods [pattern]`              | แสดง pod พร้อมตัวกรอง regex                                           |
| `kk sh <pattern> [-- cmd]`       | exec เข้า pod ที่หาได้จาก pattern                                     |
| `kk logs <pattern> [options]`    | tail logs หลาย pod ใส่ prefix ชื่อ pod ใช้ตัวเลือก `-c/-g/-f` ได้     |
| `kk images <pattern>`            | แสดง image ใน pod (ต้องมี `jq`)                                       |
| `kk restart <deploy-pattern>`    | rollout restart deployment โดยเลือกให้เหลือตัวเดียวก่อน               |
| `kk pf <pattern> <local:remote>` | port-forward pod ที่ตรง pattern                                       |
| `kk desc <pattern>`              | `kubectl describe pod`                                                |
| `kk top [pattern]`               | แสดง CPU/memory ของ pod และกรองตามชื่อได้                             |
| `kk events`                      | แสดง events ล่าสุดใน namespace                                        |
| `kk deploys`                     | สรุป deployment พร้อม ready/desired และ image แรก (มี `jq` จะสวยกว่า) |
| `kk ctx [context]`               | แสดง context หรือสลับ context ของ `kubectl`                           |

ทุกคำสั่งจะเติม `-n "$NAMESPACE"` ให้โดยอัตโนมัติ จากค่าใน `~/.kk`

## ปรัชญา

1. **Simplicity first** – สคริปต์ Bash เดียว ตรวจสอบง่าย
2. **Smart automation** – ช่วยอัตโนมัติแบบฉลาดโดยไม่ซ่อนแนวคิด Kubernetes
3. **Avoid abstraction leakage** – แต่ละคำสั่งเทียบเคียงกับ `kubectl` verb ที่คุ้นเคย
4. **Safe defaults** – ไม่ทำอะไรที่เสี่ยงโดยไม่แจ้ง
5. **Unix-style output** – ข้อความเรียบง่าย grep ได้ง่าย

## การมีส่วนร่วม

ยินดีรับ Pull Request ที่สอดคล้องกับปรัชญาของโปรเจกต์ เมื่อจะเพิ่มคำสั่งใหม่:

- เก็บทุกอย่างไว้ในสคริปต์ `kk` ไฟล์เดียว
- สร้างฟังก์ชันเป็น `cmd_<name>()`
- อัปเดตข้อความ usage และเอกสารประกอบ
- เรียก `load_namespace` ทุกครั้งที่มีการใช้ทรัพยากร Kubernetes

ขอให้สนุกกับการแก้ปัญหาบน Kubernetes!
