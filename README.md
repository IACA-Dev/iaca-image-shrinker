<h1 align="center">IACA image shrinker</h1>
<p align="center">Powered by </p>
<p align="center">
<a href="https://iaca-electronique.com">
<img style="" width="250px" src="https://www.iaca-electronique.com/img/logo.png">
</a>
</p>

___

## 📄 Purpose

This script is designed to minimize the size of a Linux image, making it more efficient for storage and distribution.
By following a series of optimization steps, thus reducing the image to its optimal size without compromising its functionality.

### ⚠️ Requirements
* MBR partition table only
* Partition count need to be between 1 and 4 (include)
* Support only `FAT` and `EXT4` file system

### 📋️ Targets supported

* Olimex A20 (`olimex-a20`)
* Raspberry (`raspberry`)

## ▶️ Usage

### From Docker *(easy)*

```bash
docker --debug build -t shrinker .
docker run --privileged -v /dev:/dev \
          -it \
          -v $(pwd):/mnt \
          shrinker -o /mnt/<output-image> -t <target> /mnt/<input-img>
```

#### Example

```bash
ls
# Result
# 2021-05-07-raspios-buster-arm64.img

docker --debug build -t shrinker .
docker run --privileged \
          -v /dev:/dev \
          -it \
          -v $(pwd):/mnt \
          shrinker -o /mnt/output.img -t raspberry /mnt/2021-05-07-raspios-buster-arm64.img

ls
# Result
# 2021-05-07-raspios-buster-arm64.img   output.img
```


### From git *(expert)*

```bash
git clone https://github.com/IACA-Dev/iaca-image-shrinker.git
cd iaca-image-shrinker/scripts
chmod +x iaca-image-shrinker.sh

iaca-image-shrinker.sh  -o "output.img" -t "target" "source img"
```

> ⚠️
> 
> Using this way can lead to dependency issue in case where your system doesn't have all required program.
> 
> ➡️ It's commended to use **Docker** usage.


#### Examples

```bash
# Olimex A20
iaca-image-shrinker.sh  -o output.img -t olimex-a20 ./official-olimex-a20-base.img

# Raspberry
iaca-image-shrinker.sh  -o output.img -t raspberry ./2021-05-07-raspios-buster-arm64.img

# No specific target (work only on target without bootloader in image)
iaca-image-shrinker.sh  -o output.img ./input-image.img

```



## 🧑‍🤝‍🧑 Contributors

* Julien FAURE [✉️ julien.faure@iaca-electronique.com](mailto:julien.faure@iaca-electronique.com) (*IACA Electronique*)
