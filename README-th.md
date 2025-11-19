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
- ยูทิลิตี้เกี่ยวกับ pod: list, exec shell, logs, describe, port-forward
- เครื่องมือแก้ปัญหา: log หลาย pod, กรอง `kubectl top`, ดู events ล่าสุด
- งาน deployment: restart รวดเร็วและสรุปสถานะให้อ่านง่าย (ถ้ามี `jq`)
- จัดการ context (`kk ctx`) เพื่อสลับ context โดยไม่แตะ namespace

## ความต้องการระบบ

- Bash 4+
- `kubectl` ที่ตั้งค่าเชื่อมต่อคลัสเตอร์ของคุณแล้ว
- เสริม (ไม่บังคับ):
  - `jq` เพื่อเอาต์พุตที่อ่านง่ายขึ้นใน `kk images` และ `kk deploys`
  - `fzf` สำหรับเลือก resource แบบ interactive เมื่อมีหลายรายการ

## การติดตั้ง

```bash
git clone git@github.com:heart/kk-Kubernetes-Power-Helper-CLI.git
cd kk-Kubernetes-Power-Helper-CLI
chmod +x kk
# หากต้องการวาง kk ไว้บน PATH
ln -s "$(pwd)/kk" /usr/local/bin/kk  # ปรับ path ตามต้องการ
```

หรือคัดลอกสคริปต์ `kk` ไปไว้ในไดเรกทอรีที่อยู่บน `PATH` ของคุณ

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

## Command Highlights

| คำสั่ง                         | คำอธิบาย                                                                                              |
| -------------------------------- | ------------------------------------------------------------------------------------------------------ |
| `kk ns [show\|set]`              | จัดการ namespace ที่เก็บไว้ใน `~/.kk`                                                                  |
| `kk pods [pattern]`              | แสดงรายชื่อ pod (มี header และกรองด้วย regex ได้)                                                     |
| `kk sh <pattern> [-- cmd]`       | exec เข้า pod ที่หาได้จาก pattern                                                                     |
| `kk logs <pattern> [options]`    | tail log หลาย pod พร้อมตัวเลือก container/grep/follow                                                 |
| `kk images <pattern>`            | แสดง image ที่ใช้ใน pod (ต้องการ `jq`)                                                                 |
| `kk restart <deploy-pattern>`    | rollout restart deployment พร้อมโหมดเลือกแบบ interactive เมื่อมีหลายตัว                               |
| `kk pf <pattern> <local:remote>` | port-forward ไปยัง pod                                                                                 |
| `kk desc <pattern>`              | `kubectl describe` pod ตาม pattern                                                                     |
| `kk top [pattern]`               | แสดง CPU/Memory ของ pod และกรองด้วยชื่อได้                                                            |
| `kk events`                      | แสดง events ล่าสุดใน namespace ปัจจุบัน                                                               |
| `kk deploys`                     | สรุป deployment: ready/desired และ image ตัวแรก (ใช้ `jq` หากมี)                                       |
| `kk ctx [context]`               | แสดงหรือสลับ `kubectl context`                                                                        |

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
