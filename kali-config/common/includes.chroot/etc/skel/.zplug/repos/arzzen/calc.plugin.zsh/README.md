# Simple zsh calculator
> This is a calculator which runs on zsh.

### Demo

![calc demo](https://cloud.githubusercontent.com/assets/6382002/13583451/b1e44d30-e4b1-11e5-9efa-804f397c1181.gif)


### Installation

1. Clone this repository to your favorite path (e.g. `~/.oh-my-zsh/plugins/calc/calc.plugin.zsh`)
2. `source` the file in your `.zshrc`
3. Restart your `zsh`

```sh
# Your .zshrc
source $HOME/.oh-my-zsh/plugins/calc/calc.plugin.zsh
```

or add to `.zshrc` via [antigen](http://antigen.sharats.me/)
```sh
antigen bundle arzzen/calc.plugin.zsh
```

### Usage
```bash
# addition
root@pc:~$ = 5+3
8

# multiplication
root@pc:~$ = '4*2'
8

# subtraction
root@pc:~$ = -4-2
-6

# division
root@pc:~$ = 5.0/2
2.5

# square root
root@pc:~$ = sqrt(2)
1.41421

# parentheses
root@pc:~$ = "(6+6)*6"
72

# convert from decimal to hexadecimal
root@pc:~$ = "[#16] 255"
16#FF

# convert from decimal to binary
root@pc:~$ = "[#2] 12"
2#1100

# convert from binary to decimal
root@pc:~$ = "2#1100"
12

# convert from hexadecimal to decimal
root@pc:~$ = "16#FF"
255

# arctangent
root@pc:~$ = atan(1)
.785398

# PI value
root@pc:~$ = PI
3.14159

# more complex
root@pc:~$ = "3.4+7/8-(5.94*(4*atan(1)))"
-15.2611
```

### Plugin location

```bash
.oh-my-zsh
└─── plugins/
     └─── calc/
          └─── calc.plugin.zsh
```
