let colorWheel = function( i, x ) {
    let r = 0;
    let g = 0;
    let b = 0;
    
    r = i === x ? 255 : 0;
    
    return { red: r, green: g, blue: b};
};

for(let i = 0; i < matrix.height; i++) {
    for(let y = 0; y < matrix.width; y++) {
        for(let x = 0; x < matrix.height; x++) {
            let showColor = colorWheel(i, x);
            setPixelColor(showColor.red, showColor.green, showColor.blue, 0, x, y);
        }
    }

    updatePixels();
    delay(250);
}
