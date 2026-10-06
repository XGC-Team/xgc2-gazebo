# xgc2-gazebo

Ubuntu 24.04 上从源码构建 Gazebo Classic 的脚本仓库。每个版本是一个独立分支。Git 里只有工具脚本，不保存 Gazebo 源码。

仓库可以克隆到任意路径。源码、压缩包、编译目录和安装结果都落在该分支工作副本里的 `gazebo/`，不进 Git。

不要把 `source env.bash` 写进 `~/.bashrc`。需要这个 Gazebo 时，在那个检出里加载。安装前缀不进 `/usr`，也不注册 `ldconfig`。

```bash
git clone -b noble-gz11 --single-branch git@github.com:XGC-Team/xgc2-gazebo.git xgc2-gazebo
cd xgc2-gazebo
./bootstrap.sh
source env.bash
```

和源码 ROS 1 一起用时，先加载 [xgc2-ros](https://github.com/XGC-Team/xgc2-ros) 对应分支的环境，再加载这里的 `env.bash`。`gazebo_ros` 是 ROS 包，不在这个仓库里。

编译最多使用 16 核，并按当时可用内存再收紧。要指定核数时设置 `GAZEBO_BUILD_JOBS`。

分支说明：

| 分支 | 内容 |
| --- | --- |
| `main` | 本说明 |
| `noble-gz11` | Gazebo Classic 11.15.1，供 Ubuntu 24.04 源码构建 XGC1 |
