3.1 Логуємося в Google Cloud Platform:
- створюємо новий Project за назвою 'main' 
- в ньому створюємо Service Account з JSON ключем
:
1.
![GCP](images/gcp_1.jpg)

---
2.
![GCP](images/gcp_2.jpg)

---
3.
![GCP](images/gcp_3.jpg)

---
4.
![GCP](images/gcp_4.jpg)

---
5.
![GCP](images/gcp_5.jpg)

---
6.
![GCP](images/gcp_6.jpg)

---
7.
![GCP](images/gcp_7.jpg)

---
8.
![GCP](images/gcp_8.jpg)

---
9.
![GCP](images/gcp_9.jpg)

---
10.
![GCP](images/gcp_10.jpg)

---

3.2 Зберігаємо створений ключ і кладемо його в папку `terraform/gcp/` під назвою main.json

3.3 Відредагуємо `terraform/gcp/providers.tf`, де вказуємо project id замість "-XXXX":

```
provider "google" {
  project = "main-XXXX"
  region  = local.region
  zone    = local.zone
  credentials = "${file("main.json")}"
}
```
