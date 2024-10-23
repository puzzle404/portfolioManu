import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["player"];
  player = null;

  connect() {
    // Inserta el reproductor de YouTube si no existe ya
    if (!document.querySelector('#player')) {
      const template = this.element;
      document.body.before(template.content.cloneNode(true));
      this.loadYouTubeAPI();
    }

    // Escuchar el evento personalizado del botón del navbar
    if (!this.listenerAdded) {
      document.addEventListener('togglePlayPause', this.playPause.bind(this));
      this.listenerAdded = true;  // Evita añadir el listener más de una vez
    }
  }

  loadYouTubeAPI() {
    // Carga la API de YouTube solo si no se ha cargado ya
    if (!window.YT) {
      var tag = document.createElement('script');
      tag.src = "https://www.youtube.com/iframe_api";
      var firstScriptTag = document.getElementsByTagName('script')[0];
      firstScriptTag.parentNode.insertBefore(tag, firstScriptTag);
    }

    // Espera a que la API de YouTube esté lista
    window.onYouTubeIframeAPIReady = () => {
      if (!this.player) { // Solo inicializa si no hay un player existente
        this.initializePlayer();
      }
    };
  }

  initializePlayer() {
    this.player = new YT.Player('youtube-video', {
      events: {
        'onReady': this.onPlayerReady.bind(this)
      }
    });
  }

  onPlayerReady() {
    console.log('Player is ready');
  }

  playPause() {
    if (this.player) {
      const playerState = this.player.getPlayerState();
      const musicIcon = document.querySelector(".music-icon");
      const playIcon = document.querySelector(".play-icon");
      if (playerState === YT.PlayerState.PLAYING) {
        this.player.pauseVideo();
        musicIcon.style.display = "none";
        playIcon.style.display = "block";
        console.log('paused event');
      } else {
        this.player.playVideo();
        playIcon.style.display = "none";
        musicIcon.style.display = "block";
        console.log('playing event');
      }
    }
  }
}
