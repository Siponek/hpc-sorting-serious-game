extends PanelContainer

signal finished

func popup(text: String):
    $MarginContainer/Label.text = text
    show()
    
    var tween = create_tween()
    tween.tween_property(self, "modulate:a", 1.0, 0.3)
    tween.tween_interval(2.0)
    tween.tween_property(self, "modulate:a", 0.0, 0.3)
    await tween.finished
    
    queue_free()