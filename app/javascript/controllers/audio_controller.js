import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["player"];
  player = null;

  connect() {
    // Inserta el reproductor de YouTube si no existe
    if (!document.querySelector('#player')) {
      const template = this.element;
      document.body.before(template.content.cloneNode(true));
      this.loadYouTubeAPI();
    }

    // Escuchar el evento personalizado del botón del navbar
    document.addEventListener('togglePlayPause', this.playPause.bind(this));
  }

  loadYouTubeAPI() {
    // Carga la API de YouTube
    var tag = document.createElement('script');
    tag.src = "https://www.youtube.com/iframe_api";
    var firstScriptTag = document.getElementsByTagName('script')[0];
    firstScriptTag.parentNode.insertBefore(tag, firstScriptTag);

    // Espera a que la API de YouTube esté lista
    window.onYouTubeIframeAPIReady = () => {
      this.initializePlayer();
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
    // Player is ready, but we don't need to do anything specific here
  }

  playPause() {
    const playerState = this.player.getPlayerState();
    const musicIcon = document.querySelector(".music-icon");
    const playIcon = document.querySelector(".play-icon");
    const pauseIcon = document.querySelector(".pause-icon");

    if (playerState === YT.PlayerState.PLAYING) {
      this.player.pauseVideo();
      musicIcon.style.display = "none";
      playIcon.style.display = "block";
      console.log('paused event')
    } else {
      console.log('playing event')


      this.player.playVideo();
      playIcon.style.display = "none";
      musicIcon.style.display = "block";
    }
  }
}
