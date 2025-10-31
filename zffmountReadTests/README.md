# `zffmount` read tests

> the containers `zfftest.z01` and `zfftest.e01` were acquired with the orders
> `zffacquire physical -i /dev/loop0 -o zfftest` (1m10s 115Mb/s)
> and
> `ewfacquire -c fast -t zfftest /dev/loop0` (2m47s 49Mb/s),
> and saved on a USB3 flash drive.


## `RAW`

```bash
ls -l /mnt/zfftest.*
# -rwxrwxrwx 1 root root 8589934592 30 oct.  10:53 /mnt/zfftest.raw
# -rwxrwxrwx 1 root root 1740743559 30 oct.  11:04 /mnt/zfftest.z01
# -rwxrwxrwx 1 root root 1794493531 30 oct.  12:22 /mnt/zfftest.e01

sha1sum /mnt/zfftest.raw
# 957101f373f6f888becc44a4ea6266b7e6e8aca2  /mnt/zfftest.raw
```

```bash
flush () { sync && sudo sysctl -q vm.drop_caches=3; }
```

```bash
for loop in 1 2 3 4
do
 flush
 pv -btr /mnt/zfftest.raw > /dev/null
done
# 8,00GiO 0:00:13 [597MiO/s]
# 8,00GiO 0:00:13 [600MiO/s]
# 8,00GiO 0:00:13 [604MiO/s]
# 8,00GiO 0:00:13 [602MiO/s]
```


## `ZFF`

```bash
mkdir /tmp/zfftest

zffmount -i /mnt/zfftest.z01 -m /tmp/zfftest

ls -l /tmp/zfftest/object_1/
# -r-xr-xr-x 1 pascal pascal 8589934592 30 oct.  09:50 zff_image.dd

sha1sum /tmp/zfftest/object_1/zff_image.dd 
# 957101f373f6f888becc44a4ea6266b7e6e8aca2  /tmp/zfftest/object_1/zff_image.dd
```

```bash
for loop in 1 2 3 4
do
 flush
 pv -btr /tmp/zfftest/object_1/zff_image.dd > /dev/null
done
# 8,00GiO 0:00:28 [288MiO/s]
# 8,00GiO 0:00:28 [285MiO/s]
# 8,00GiO 0:00:27 [296MiO/s]
# 8,00GiO 0:00:27 [295MiO/s]
```

```bash
sudo mount /tmp/zfftest/object_1/zff_image.dd /mnt/

du -sh /mnt/
# 4,1G	/mnt/

find /mnt/ -type f | wc -l
# 33866

flush && time ( find /mnt/ -type f -exec tac '{}' \; | sha1sum )
# 57c472b90d49f95c0f994e02112f626a9c96b55b  -
# real 3m00,962s
# user 1m10,681s
# sys  0m40,021s
```


## `EWF`

```bash
mkdir /tmp/ewftest

ewfmount /mnt/zfftest.e01 /tmp/ewftest/

ls -l /tmp/ewftest/
# -r--r--r-- 1 pascal pascal 8589934592 30 oct.  12:44 ewf1

sha1sum /tmp/ewftest/ewf1 
# 957101f373f6f888becc44a4ea6266b7e6e8aca2  /tmp/ewftest/ewf1
```

```bash
for loop in 1 2 3 4
do
 flush
 pv -btr /tmp/ewftest/ewf1 > /dev/null
done
# 8,00GiO 0:00:50 [161MiO/s]
# 8,00GiO 0:00:59 [138MiO/s]
# 8,00GiO 0:00:54 [151MiO/s]
# 8,00GiO 0:00:57 [141MiO/s]
```

```bash
sudo mount /tmp/ewftest/ewf1 /mnt/

du -sh /mnt/
# 4,1G	/mnt/

find /mnt/ -type f | wc -l
# 33866

flush && time ( find /mnt/ -type f -exec tac '{}' \; | sha1sum )
# 57c472b90d49f95c0f994e02112f626a9c96b55b  -
# real 3m44,605s
# user 1m30,660s
# sys  0m47,059s
```
